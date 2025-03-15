import path from 'path';
import express from 'express';

export function setupCacheMiddleware(BUILD_DIR: string, publicDir: string) {
  return [
    // Assets do Vite/Remix (long-term caching)
    {
      path: '/assets',
      middleware: express.static(path.join(BUILD_DIR, 'client/assets'), {
        maxAge: '1y',
        immutable: true,
      })
    },
    // Static client files
    {
      path: '/',
      middleware: express.static(path.join(BUILD_DIR, 'client'), {
        maxAge: '30d'
      })
    },
    // Compatibility with /build paths
    {
      path: '/build',
      middleware: express.static(path.join(BUILD_DIR, 'client'), {
        maxAge: '1y',
        immutable: true,
      })
    },
    // Serve static files from the public directory
    {
      path: '/',
      middleware: express.static(publicDir)
    }
  ]
}