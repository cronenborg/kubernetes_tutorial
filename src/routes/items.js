const db = require('../db');

async function routes(fastify, options) {
  // Get all items
  fastify.get('/', async (request, reply) => {
    const items = db.findAll();
    return { items, count: items.length };
  });

  // Get single item
  fastify.get('/:id', async (request, reply) => {
    const item = db.findById(request.params.id);
    if (!item) {
      reply.code(404);
      return { error: 'Item not found' };
    }
    return item;
  });

  // Create item
  fastify.post('/', {
    schema: {
      body: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string' },
          description: { type: 'string' }
        }
      }
    }
  }, async (request, reply) => {
    const item = db.create(request.body);
    reply.code(201);
    return item;
  });

  // Update item
  fastify.put('/:id', {
    schema: {
      body: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          description: { type: 'string' }
        }
      }
    }
  }, async (request, reply) => {
    const item = db.update(request.params.id, request.body);
    if (!item) {
      reply.code(404);
      return { error: 'Item not found' };
    }
    return item;
  });

  // Delete item
  fastify.delete('/:id', async (request, reply) => {
    const deleted = db.delete(request.params.id);
    if (!deleted) {
      reply.code(404);
      return { error: 'Item not found' };
    }
    reply.code(204);
    return;
  });
}

module.exports = routes;