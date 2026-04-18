import { UsageRecord } from '../models.js';

export abstract class BaseProvider {
  protected extraHeaders: Record<string, string> = {};

  constructor(protected baseUrl: string, protected apiKey: string, extraHeaders: Record<string, string> = {}) {
    // 1. Handle multi-line input: take the first non-empty line
    const urlLines = (baseUrl || "").split('\n').map(l => l.trim()).filter(l => l.length > 0);
    this.baseUrl = urlLines.length > 0 ? urlLines[0].replace(/\/$/, '') : "";

    const keyLines = (apiKey || "").split('\n').map(l => l.trim()).filter(l => l.length > 0);
    this.apiKey = keyLines.length > 0 ? keyLines[0] : "";

    // 2. Strict printable ASCII only (32-126) to avoid URL errors
    this.baseUrl = this.baseUrl.split('').filter(c => c.charCodeAt(0) >= 32 && c.charCodeAt(0) <= 126).join('');
    this.apiKey = this.apiKey.split('').filter(c => c.charCodeAt(0) >= 32 && c.charCodeAt(0) <= 126).join('');

    this.extraHeaders = extraHeaders;
  }
  
  abstract chatCompletion(params: any): Promise<any>;
  abstract listModels(): Promise<string[]>;
  abstract extractUsage(response: any): Partial<UsageRecord>;

  protected getHeaders(): Record<string, string> {
    return {
      "Authorization": `Bearer ${this.apiKey}`,
      "Content-Type": "application/json",
      ...this.extraHeaders
    };
  }
}
