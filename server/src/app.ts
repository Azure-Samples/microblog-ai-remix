
import express from 'express';
import morgan from 'morgan';
import { createRequestHandler } from '@remix-run/express';
import { compressionMiddleware, setupCacheMiddleware } from './middleware/index.js';
import apiRoutes from './routes/index.js';
import { loadEnvVariables, NODE_ENV, PORT } from './config/env.js';
import { PATHS } from './config/paths.js';

loadEnvVariables();

const buildUrl = new URL(`file://${PATHS.serverBuild}`);
const build = await import(buildUrl.href);

const app = express();

app.use(compressionMiddleware);

if (NODE_ENV === 'development') {
  app.use(morgan('tiny'));
}

const cacheMiddlewares = setupCacheMiddleware(PATHS.build, PATHS.public);
cacheMiddlewares.forEach(({ path: routePath, middleware }) => {
  app.use(routePath, middleware);
});

app.use(apiRoutes);

app.all(
  "*",
  createRequestHandler({
    build,
    mode: NODE_ENV,
  })
);

export function startServer() {
  app.listen(Number(PORT), () => {
    console.log(`Server is running on http://localhost:${PORT}`);
  });
}