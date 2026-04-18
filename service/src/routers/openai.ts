import { FastifyInstance, FastifyRequest } from 'fastify';
import { Readable } from 'node:stream';
import { parseModelName } from '../core/router.js';
import { createProvider } from '../providers/index.js';
import { parseClient } from '../core/usage.js';

// Extend FastifyInstance to include our custom decorations
declare module 'fastify' {
  interface FastifyInstance {
    configManager: any;
    usageTracker: any;
  }
}

export default async function openaiRouter(fastify: FastifyInstance) {
  const { configManager, usageTracker } = fastify;

  fastify.post('/v1/chat/completions', async (request: FastifyRequest, reply) => {
    const body = request.body as any;
    const model = body.model;
    const isStream = body.stream === true;
    
    if (!model) return reply.status(422).send({ error: "model is required" });

    const [providerName, actualModel] = parseModelName(model);
    const config = configManager.get();
    const effectiveProvider = providerName || config.default_provider;
    
    const enabled = configManager.getEnabledProviders();
    const providerCfg = enabled[effectiveProvider];
    
    if (!providerCfg) {
        console.warn(`[Router] Provider not found: ${effectiveProvider}`);
        return reply.status(404).send({ error: `Provider ${effectiveProvider} not found or disabled` });
    }

    const apiKey = configManager.getProviderApiKey(effectiveProvider);
    if (!apiKey) {
        console.warn(`[Router] API Key missing for: ${effectiveProvider}`);
        return reply.status(503).send({ error: `Provider ${effectiveProvider} API key not configured` });
    }

    console.log(`[Router] Request: ${effectiveProvider}/${actualModel} (stream: ${isStream})`);
    
    // Pass along incoming headers to help with provider validation
    const provider = createProvider(
        effectiveProvider, 
        providerCfg, 
        apiKey, 
        request.headers as Record<string, string>
    );
    
    const requestBody = { ...body, model: actualModel };
    const startTime = Date.now();
    
    try {
        const result = await provider.chatCompletion(requestBody);
        
        if (isStream) {
            // Standardizing stream forwarding using Node.js Readable.fromWeb
            if (result && typeof result.getReader === 'function') {
                const nodeStream = Readable.fromWeb(result);
                
                usageTracker.record({
                    timestamp: new Date().toISOString(),
                    client_id: parseClient(request.headers),
                    latency_ms: 0,
                    provider: effectiveProvider,
                    model: actualModel,
                    prompt_tokens: 0,
                    completion_tokens: 0,
                    total_tokens: 0,
                    cost_estimate: 0
                });

                return reply
                    .type('text/event-stream')
                    .header('Cache-Control', 'no-cache')
                    .header('Connection', 'keep-alive')
                    .send(nodeStream);
            }
        }

        const latency = Date.now() - startTime;
        const usage = provider.extractUsage(result);
        usageTracker.record({
            timestamp: new Date().toISOString(),
            client_id: parseClient(request.headers),
            latency_ms: latency,
            cost_estimate: 0,
            ...usage as any
        });

        return result;
    } catch (err: any) {
        console.error(`[Router] Error: ${err.message}`);
        
        // Try to extract status code from error message (e.g. "HTTP 403: ...")
        const statusMatch = err.message.match(/HTTP (\d{3})/);
        const statusCode = statusMatch ? parseInt(statusMatch[1]) : 500;
        
        return reply.status(statusCode).send({ 
            error: {
                message: err.message,
                type: "upstream_error",
                provider: effectiveProvider
            }
        });
    }
  });

  fastify.get('/v1/models', async () => {
    const config = configManager.get();
    const models: any[] = [];
    const providers = config.providers || {};
    for (const [name, cfg] of Object.entries(providers) as [string, any][]) {
        if (cfg.enabled) {
            const modelsList = cfg.enabled_models || cfg.models || [];
            for (const m of modelsList) {
                models.push({ 
                    id: `${name}/${m}`, 
                    object: "model", 
                    created: Math.floor(Date.now() / 1000),
                    owned_by: name 
                });
            }
        }
    }
    return { object: "list", data: models };
  });
}
