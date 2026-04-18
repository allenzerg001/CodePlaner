import Fastify from 'fastify';
import cors from '@fastify/cors';
import openaiRouter from './routers/openai.js';
import adminRouter from './routers/admin.js';
import { ConfigManager } from './config.js';
import { UsageTracker } from './core/usage.js';

// Simple logger configuration without dynamic transports to ensure compatibility with ncc/single-file build
const fastify = Fastify({ 
  logger: true
});

const start = async () => {
  try {
    await fastify.register(cors);

    const configManager = new ConfigManager();
    configManager.load();
    const usageTracker = new UsageTracker();

    // Share instances across the app
    fastify.decorate('configManager', configManager);
    fastify.decorate('usageTracker', usageTracker);

    await fastify.register(openaiRouter);
    await fastify.register(adminRouter);

    const config = configManager.get();
    await fastify.listen({ port: config.server.port, host: config.server.host });
    console.log(`[Main] Server listening on ${config.server.host}:${config.server.port}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
