import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const PATHS = {
  root: path.resolve(__dirname, '../../../'),
  build: path.resolve(__dirname, '../../../build'),
  public: path.resolve(__dirname, '../../../public'),
  serverBuild: path.resolve(__dirname, '../../../build/server/index.js')
};