import { BaseProvider } from './base.js';
import { DeepseekProvider } from './deepseek.js';
import { ProviderConfig } from '../models.js';

export function createProvider(name: string, config: ProviderConfig, apiKey: string, incomingHeaders: Record<string, string> = {}): BaseProvider {
  // Extra headers to satisfy 'Coding Agent' checks (e.g. Moonshot)
  const extraHeaders: Record<string, string> = {};
  const isKimi = name === 'moonshot' || config.base_url.toLowerCase().includes('kimi');

  if (isKimi) {
    // For Kimi, we've verified that transparently forwarding the IDE's own identity works best.
    // We only need to ensure the Authorization and Content-Type are standard.
    
    // Normalize and pick the original user-agent if available
    const normalizedIncoming: Record<string, string> = {};
    for (const [key, value] of Object.entries(incomingHeaders)) {
      if (value) normalizedIncoming[key.toLowerCase()] = value;
    }
    
    if (normalizedIncoming['user-agent']) {
      extraHeaders['User-Agent'] = normalizedIncoming['user-agent'];
    } else {
      // Fallback if no UA is provided
      extraHeaders['User-Agent'] = 'opencode/1.4.11 ai-sdk/provider-utils/4.0.23 runtime/bun/1.3.11';
    }
  } else {
    // For other providers, use standard forwarding logic
    const headersToForward = ['user-agent', 'x-client-name', 'x-client-version', 'x-cursor-id', 'x-continue-id'];
    const normalizedIncoming: Record<string, string> = {};
    for (const [key, value] of Object.entries(incomingHeaders)) {
      if (value) normalizedIncoming[key.toLowerCase()] = value;
    }

    for (const key of headersToForward) {
      if (normalizedIncoming[key]) {
        extraHeaders[key] = normalizedIncoming[key];
      }
    }
  }

  switch (name) {
    case 'deepseek':
      return new DeepseekProvider(config.base_url, apiKey, extraHeaders);
    default:
      // Generic OpenAI provider
      return new DeepseekProvider(config.base_url, apiKey, extraHeaders);
  }
}

export { BaseProvider, DeepseekProvider };
