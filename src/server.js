import './config/env.js';
import { createApp } from './app.js';
import { connectDB, disconnectDB } from './config/db.js';

const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/crud_demo';

async function start() {
  try {
    await connectDB(MONGODB_URI);
  } catch (err) {
    console.error('Could not connect to MongoDB:', err.message);
    console.error(`Check that MongoDB is running and MONGODB_URI is correct (${MONGODB_URI}).`);
    process.exit(1);
  }

  const server = createApp().listen(PORT, () => {
    console.log(`API listening on http://localhost:${PORT}`);
  });

  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, async () => {
      console.log(`\n${signal} received, shutting down...`);
      server.close(async () => {
        await disconnectDB();
        process.exit(0);
      });
    });
  }
}

start();
