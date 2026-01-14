const fastify = require('fastify')({ logger: true });
const itemsRoutes = require('./routes/items');

const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

// Register routes
fastify.register(itemsRoutes, { prefix: '/items' });

// Health check endpoint
fastify.get('/health', async (request, reply) => {
  return { status: 'ok', timestamp: new Date().toISOString() };
});

// Root endpoint
fastify.get('/', async (request, reply) => {
  return {
    message: 'Fastify CRUD API for Kubernetes Tutorial',
    version: '1.0.0',
    endpoints: {
      health: 'GET /health',
      items: {
        getAll: 'GET /items',
        getOne: 'GET /items/:id',
        create: 'POST /items',
        update: 'PUT /items/:id',
        delete: 'DELETE /items/:id'
      }
    }
  };
});

const start = async () => {
  try {
    await fastify.listen({ 
      port: PORT, 
      host: '0.0.0.0' // Important for Docker/K8s
    });
    console.log(`Server running on port ${PORT}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();