import { BaseProvider } from './base.js';
import { UsageRecord } from '../models.js';

export class DeepseekProvider extends BaseProvider {
  async chatCompletion(params: any) {
    const isStream = params.stream === true;
    const headers = this.getHeaders();
    console.log(`[Provider] Outgoing Headers: ${JSON.stringify(headers)}`);

    const response = await fetch(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify(params)
    });
    
    if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${await response.text()}`);
    }

    if (isStream) {
      return response.body; // Return the ReadableStream
    }
    
    return response.json();
  }

  async listModels(): Promise<string[]> {
    try {
      const response = await fetch(`${this.baseUrl}/models`, {
        headers: this.getHeaders()
      });
      if (!response.ok) throw new Error();
      const result: any = await response.json();
      return result.data.map((m: any) => m.id);
    } catch {
      return ["deepseek-chat", "deepseek-coder"];
    }
  }

  extractUsage(response: any): Partial<UsageRecord> {
    const usage = response.usage || {};
    return {
      provider: "deepseek",
      model: response.model || "unknown",
      prompt_tokens: usage.prompt_tokens || 0,
      completion_tokens: usage.completion_tokens || 0,
      total_tokens: usage.total_tokens || 0,
    };
  }
}
