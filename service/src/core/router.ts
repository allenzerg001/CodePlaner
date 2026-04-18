export const PROVIDER_ALIASES: Record<string, string> = {
  "volcano": "volcengine",
};

export function canonicalProviderName(name: string | null): string | null {
  if (!name) return null;
  return PROVIDER_ALIASES[name] || name;
}

export function parseModelName(model: string): [string | null, string] {
  if (!model) return [null, ""];
  if (model.includes("/")) {
    const [provider, name] = model.split("/", 2);
    return [canonicalProviderName(provider), name];
  }
  return [null, model];
}
