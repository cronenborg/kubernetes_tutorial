// Simple in-memory database for demo purposes
// In production, use a real database like PostgreSQL or MongoDB

class Database {
  constructor() {
    this.items = new Map();
    this.currentId = 1;
  }

  create(data) {
    const id = this.currentId++;
    const item = {
      id,
      ...data,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    this.items.set(id, item);
    return item;
  }

  findAll() {
    return Array.from(this.items.values());
  }

  findById(id) {
    return this.items.get(parseInt(id));
  }

  update(id, data) {
    const item = this.items.get(parseInt(id));
    if (!item) return null;
    
    const updated = {
      ...item,
      ...data,
      id: item.id,
      createdAt: item.createdAt,
      updatedAt: new Date().toISOString()
    };
    this.items.set(parseInt(id), updated);
    return updated;
  }

  delete(id) {
    return this.items.delete(parseInt(id));
  }
}

module.exports = new Database();