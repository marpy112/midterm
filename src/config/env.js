// Load .env from the project root regardless of the process working directory,
// so `npm --prefix`, systemd units, and IDE launchers all behave the same.
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

export const projectRoot = fileURLToPath(new URL('../../', import.meta.url));

dotenv.config({ path: new URL('.env', new URL('../../', import.meta.url)) });
