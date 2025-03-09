import { createRequestHandler } from '@remix-run/express';
import express, { Request, Response } from 'express';
import compression from 'compression';
import morgan from 'morgan';
import path from 'path';
import { fileURLToPath } from 'url';
import * as dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

dotenv.config({ path: path.resolve(__dirname, '../../.env') });
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const requiredEnvVars = [
  'AZURE_OPENAI_API_KEY',
  'AZURE_OPENAI_ENDPOINT',
  'AZURE_OPENAI_DEPLOYMENT_NAME',
  'AZURE_OPENAI_API_VERSION'
];

if (process.env.NODE_ENV === 'development') {
  const missingVars = requiredEnvVars.filter(envVar => !process.env[envVar]);
  if (missingVars.length > 0) {
    console.warn(`Missing environment variables: ${missingVars.join(', ')}`);
    console.warn('Some functionalities may not work correctly in development mode.');
  }
} else {
  for (const envVar of requiredEnvVars) {
    if (!process.env[envVar]) {
      throw new Error(`${envVar} must be configured in environment variables`);
    }
  }
}

const BUILD_DIR = path.join(__dirname, '../../build');

const MODE = process.env.NODE_ENV;

const buildPath = path.join(BUILD_DIR, 'server/index.js');
const buildUrl = new URL(`file://${buildPath}`);
const build = await import(buildUrl.href);

const app = express();

app.use(compression({
  level: 6,
  threshold: 1024,
  filter: (req: Request, res: Response) => {
    if (req.headers['x-no-compression']) {
      return false; // don't compress responses with this request header
    }
    return compression.filter(req, res); // fallback to standard filter function
  }
}));

if (MODE === 'development') {
  app.use(morgan('tiny'));
}

// Serve static files from the build directory and public directory
app.use('/assets', express.static(path.join(BUILD_DIR, 'client/assets'), {
  maxAge: '1y',
  immutable: true,
}));

app.use(express.static(path.join(BUILD_DIR, 'client'), {
  maxAge: '30d'
}));

app.use('/build', express.static(path.join(BUILD_DIR, 'client'), {
  maxAge: '1y',
  immutable: true,
}));

app.use(express.static(path.join(__dirname, '../../public')));

app.get('/health', (req: Request, res: Response) => {
  res.status(200).send('OK');
});

app.all(
  "*",
  createRequestHandler({
    build,
    mode: MODE,
  })
);

const port = process.env.PORT || 3000;

export function startServer() {
  app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
  });
}