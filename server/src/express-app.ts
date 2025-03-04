import { createRequestHandler } from '@remix-run/express';
import express from 'express';
import compression from 'compression';
import morgan from 'morgan';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BUILD_DIR = path.join(__dirname, '../../build');

// Environment variable to determine the mode (development/production)
const MODE = process.env.NODE_ENV;

// File path to the server build/server/index.js
const buildPath = path.join(BUILD_DIR, 'server/index.js');
const buildUrl = new URL(`file://${buildPath}`);
const build = await import(buildUrl.href);

// Create an Express application
const app = express();

// Enable logging in development mode
app.use(compression());

if (MODE === 'development') {
  app.use(morgan('tiny'));
}

// Serve static files from the build directory
app.use('/build', express.static(path.join(BUILD_DIR, 'client')));
app.use(express.static(path.join(__dirname, '../../public')));

app.get('/health', (req, res) => {
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
