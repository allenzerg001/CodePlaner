import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { AppConfig, ProviderConfig } from './models.js';
import { decrypt_api_key } from './crypto.js';

export class ConfigManager {
  private config: AppConfig | null = null;
  private configPath: string;

  constructor() {
    const home = os.homedir();
    this.configPath = path.join(home, '.codingplan', 'config.json');
  }

  load() {
    if (fs.existsSync(this.configPath)) {
      try {
        const file = fs.readFileSync(this.configPath, 'utf8');
        const data = JSON.parse(file);
        
        // Decrypt all provider API keys
        if (data.providers) {
          for (const name in data.providers) {
            const p = data.providers[name] as ProviderConfig;
            if (p.api_key_encrypted) {
              p.api_key = decrypt_api_key(p.api_key_encrypted);
            }
          }
        }
        
        this.config = data as AppConfig;
        console.log(`[Config] Loaded config from ${this.configPath}`);
      } catch (err) {
        console.error(`[Config] Failed to load config: ${err}`);
        this.config = this.getDefaultConfig();
      }
    } else {
      console.warn(`[Config] Config file not found at ${this.configPath}, using defaults.`);
      this.config = this.getDefaultConfig();
    }
  }

  get(): AppConfig {
    if (!this.config) {
      this.load();
    }
    
    // Override with environment variables if provided
    const envPort = process.env.PORT || process.env.SERVICE_PORT;
    if (envPort) {
      this.config!.server.port = parseInt(envPort, 10);
    }
    const envHost = process.env.HOST || process.env.SERVICE_HOST;
    if (envHost) {
      this.config!.server.host = envHost;
    }
    
    return this.config!;
  }

  getProviderApiKey(name: string): string {
    const cfg = this.get().providers[name];
    return cfg?.api_key || "";
  }

  getEnabledProviders(): Record<string, ProviderConfig> {
    const result: Record<string, ProviderConfig> = {};
    const providers = this.get().providers || {};
    for (const [name, cfg] of Object.entries(providers)) {
      if (cfg.enabled) {
        result[name] = cfg;
      }
    }
    return result;
  }

  private getDefaultConfig(): AppConfig {
    return {
      server: { host: '127.0.0.1', port: 9800 },
      default_provider: 'deepseek',
      fallback_enabled: true,
      providers: {}
    };
  }
}
