import './config/env.js';
import { connectDB, disconnectDB } from './config/db.js';
import { Task } from './models/Task.js';

const samples = [
  { title: 'Write project README', description: 'Document setup and endpoints', status: 'done' },
  { title: 'Add validation', description: 'Validate request bodies', status: 'in-progress' },
  { title: 'Deploy to staging', status: 'todo', dueDate: new Date(Date.now() + 7 * 864e5) },
];

await connectDB(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/crud_demo');
await Task.deleteMany({});
const created = await Task.insertMany(samples);
console.log(`Seeded ${created.length} tasks.`);
await disconnectDB();
