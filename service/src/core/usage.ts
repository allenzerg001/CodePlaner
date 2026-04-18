import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs';
import { Database } from 'bun:sqlite';
import { UsageRecord } from '../models.js';

export function parseClient(headers: Record<string, string | string[] | undefined>): string {
  // 1. Check common custom headers sent by AI IDEs
  const clientName = headers['x-client-name'] as string || headers['X-Client-Name'] as string;
  if (clientName) {
    if (clientName.toLowerCase().includes('opencode')) return 'OpenCode';
    if (clientName.toLowerCase().includes('claude')) return 'Claude Code';
    if (clientName.toLowerCase().includes('roo')) return 'Roo Code';
    return clientName;
  }

  // 2. Fallback to User-Agent
  const userAgent = headers['user-agent'] as string || headers['User-Agent'] as string;
  if (!userAgent) return 'Unknown';
  
  const ua = userAgent.toLowerCase();
  if (ua.includes('opencode')) return 'OpenCode';
  if (ua.includes('claudecode')) return 'Claude Code';
  if (ua.includes('continue')) return 'Continue';
  if (ua.includes('roo-code')) return 'Roo Code';
  if (ua.includes('cursor')) return 'Cursor';
  
  if (userAgent.includes('/')) {
    return userAgent.split('/')[0];
  }
  return userAgent.split(' ')[0] || 'Unknown';
}

export class UsageTracker {
  private db: Database;

  constructor() {
    const home = os.homedir();
    const dbDir = path.join(home, '.codingplan');
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true });
    }
    const dbPath = path.join(dbDir, 'usage.db');
    
    this.db = new Database(dbPath);
    this.initDb();
  }

  private initDb() {
    this.db.run(`
      CREATE TABLE IF NOT EXISTS usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        client_id TEXT,
        provider TEXT NOT NULL,
        model TEXT NOT NULL,
        prompt_tokens INTEGER DEFAULT 0,
        completion_tokens INTEGER DEFAULT 0,
        total_tokens INTEGER DEFAULT 0,
        latency_ms INTEGER DEFAULT 0,
        cost_estimate REAL DEFAULT 0.0
      )
    `);
  }

  record(record: UsageRecord) {
    console.log(`[Usage] ${record.provider}/${record.model} by ${record.client_id} - ${record.total_tokens} tokens`);
    
    try {
      const stmt = this.db.prepare(`
        INSERT INTO usage (timestamp, client_id, provider, model, prompt_tokens, completion_tokens, total_tokens, latency_ms, cost_estimate)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);
      
      stmt.run(
        record.timestamp,
        record.client_id,
        record.provider,
        record.model,
        record.prompt_tokens,
        record.completion_tokens,
        record.total_tokens,
        record.latency_ms,
        record.cost_estimate
      );
    } catch (err) {
      console.error(`[Usage] Failed to record usage to DB: ${err}`);
    }
  }

  getTodayStats() {
    const todayStr = new Date().toISOString().split('T')[0];
    
    try {
      const stmt = this.db.prepare("SELECT * FROM usage WHERE timestamp LIKE ?");
      const rows = stmt.all(`${todayStr}%`) as any[];
      
      return {
        total_requests: rows.length,
        total_tokens: rows.reduce((sum, r) => sum + r.total_tokens, 0),
        total_prompt_tokens: rows.reduce((sum, r) => sum + r.prompt_tokens, 0),
        total_completion_tokens: rows.reduce((sum, r) => sum + r.completion_tokens, 0),
        by_provider: this.aggregateByProvider(rows),
        by_client: this.aggregateByClient(rows),
      };
    } catch (err) {
      console.error(`[Usage] Failed to query today stats: ${err}`);
      return {
        total_requests: 0,
        total_tokens: 0,
        total_prompt_tokens: 0,
        total_completion_tokens: 0,
        by_provider: {},
        by_client: {},
      };
    }
  }

  private aggregateByProvider(records: any[]) {
    const result: Record<string, any> = {};
    for (const r of records) {
      if (!result[r.provider]) {
        result[r.provider] = { requests: 0, tokens: 0 };
      }
      result[r.provider].requests += 1;
      result[r.provider].tokens += r.total_tokens;
    }
    return result;
  }

  private aggregateByClient(records: any[]) {
    const result: Record<string, any> = {};
    for (const r of records) {
      if (!result[r.client_id]) {
        result[r.client_id] = { requests: 0, tokens: 0 };
      }
      result[r.client_id].requests += 1;
      result[r.client_id].tokens += r.total_tokens;
    }
    return result;
  }
}
