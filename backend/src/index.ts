import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import rateLimit from 'express-rate-limit';
import { router } from './routes';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Rate limiting for generation endpoints
const generationLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { error: 'Too many requests', message: 'Please wait before generating more listings' },
});
app.use('/api/v1/locations/:placeId', generationLimiter);

// Serve uploaded images as static files
// cwd-based so it works from source (dev) and compiled dist (docker):
// __dirname-relative resolved to dist/uploads and 404'd in production
app.use('/images', express.static(path.resolve(process.cwd(), 'uploads', 'images')));

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api/v1', router);

// Start server
app.listen(PORT, () => {
  console.log(`StaySpot API running on http://localhost:${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

export default app;
