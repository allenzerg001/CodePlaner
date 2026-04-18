export interface ProviderConfig {
  base_url: string;
  api_key_encrypted?: string;
  api_key?: string; // Decrypted version used internally
  models: string[];
  enabled_models?: string[];
  enabled: boolean;
}

export interface AppConfig {
  server: {
    host: string;
    port: number;
    allow_lan?: boolean;
  };
  default_provider: string;
  fallback_enabled: boolean;
  local_api_key?: string;
  providers: Record<string, ProviderConfig>;
}

export interface UsageRecord {
  timestamp: string;
  client_id: string;
  provider: string;
  model: string;
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
  latency_ms: number;
  cost_estimate: number;
}
