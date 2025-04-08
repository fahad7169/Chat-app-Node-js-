import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import pool from '../models/db';

export const verifyToken = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  const token = req.headers.authorization?.split(" ")[1];

  if (!token) {
    res.status(401).json({ error: "No token provided" });
    return;
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!);
    req.user = decoded as { id: string };
    next();
  } catch (error: any) {
    // Token is invalid or expired
    try {
      // Decode without verifying to extract the user ID
      const decoded: any = jwt.decode(token);
      const userId = decoded?.id;

      if (userId) {
        // Remove the user from active_users table
        await pool.query('DELETE FROM active_users WHERE id = $1', [userId]);
        console.log(`Removed user ${userId} from active_users due to expired/invalid token`);
      }
    } catch (decodeErr) {
      console.error("Failed to decode token:", decodeErr);
    }

    res.status(401).json({ error: "Invalid Token" });
  }
};
