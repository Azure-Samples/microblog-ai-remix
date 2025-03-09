import { Request, Response, Router } from "express";

const router = Router();

router.get("/health", (req: Request, res: Response) => {
  res.status(200).send("OK");
});

export default router;