import compression from 'compression';
import { Request, Response } from 'express';

export const compressionMiddleware = compression({
  level: 6,
  threshold: 1024,
  filter: (req: Request, res: Response) => {
    if (req.headers['x-no-compression']) {
      return false; // don't compress responses with this request header
    }
    return compression.filter(req, res); // fallback to standard filter function
  },
});