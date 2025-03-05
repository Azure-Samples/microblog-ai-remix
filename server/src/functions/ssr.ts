import { app } from '@azure/functions';

import { createRequestHandler } from '@remix-run/express';

import path from 'path';
import { pathToFileURL, fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const buildPath = path.resolve(__dirname, '../../../../build/server/index.js');

const buildUrl = pathToFileURL(buildPath).href;
const build = await import(buildUrl);

app.setup({ enableHttpStream: true });

app.http('ssr', {
  methods: [
    'GET',
    'POST',
    'DELETE',
    'HEAD',
    'PATCH',
    'PUT',
    'OPTIONS',
    'TRACE',
    'CONNECT'
  ],
  authLevel: 'anonymous',
  handler: (request, context) => {
    const expressHandler = createRequestHandler({
      build,
      mode: process.env.NODE_ENV,
    });

    return {
      status: 200,
      jsonBody: 'Function is configured for compatibility only'
    }
  },
  route: '{*path}',
});