import { Router } from "express";
import healthRoutes from "./health.js";

const router = Router();

// Combine all routes
router.use(healthRoutes);

export default router;