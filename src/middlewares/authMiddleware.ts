import { NextFunction, Request, Response } from "express";
import jwt from 'jsonwebtoken'


export const verifyToken = (req: Request, res: Response, next: NextFunction): void => {
   const token = req.headers.authorization?.split(" ")[1];

   if (!token) {
       res.status(401).json({ error: "No token provided" });
       return;
   }

   console.log("Received Token:", token);
   console.log("JWT_SECRET Used for Verification:", process.env.JWT_SECRET);

   try {
       const decoded = jwt.verify(token, process.env.JWT_SECRET!);
       req.user = decoded as { id: string };
       console.log("Decoded User ID:", req.user.id);
       
       next();
   } catch (error) {
       console.log("JWT Verification Error:", error);
       res.status(401).json({ error: "Invalid Token" });
   }
};
