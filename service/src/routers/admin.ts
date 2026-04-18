import { FastifyInstance } from 'fastify';

export default async function adminRouter(fastify: FastifyInstance) {
  const { configManager, usageTracker } = fastify;

  fastify.get('/admin/status', async () => {
    const config = configManager.get();
    const enabled = Object.entries(config.providers)
      .filter(([_, cfg]: [string, any]) => cfg.enabled)
      .map(([name, cfg]: [string, any]) => ({
        name,
        enabled: cfg.enabled,
        connected: true,
        models: cfg.enabled_models || cfg.models,
      }));
    return { providers: enabled };
  });

  fastify.get('/admin/usage', async () => {
    return usageTracker.getTodayStats();
  });

  fastify.post('/admin/reload-config', async () => {
    configManager.load();
    return { status: 'ok' };
  });
}
