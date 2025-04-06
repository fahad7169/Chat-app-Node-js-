import { Request, Response } from "express";
import pool from "../models/db";
import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'
import { config  } from "dotenv";
import { loggedInUsers } from "..";
config();


const SALT_ROUNDS= 10;
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;

export const register = async(req:Request, res: Response)=>{

     const {username,email,password} = req.body;
     try{
        const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS)
        const result = await pool.query(
            'INSERT INTO users (username, email, password) VALUES ($1, $2, $3) RETURNING *',
            [username, email, hashedPassword]
        );

        const user= result.rows[0];

        res.status(201).json({
            user
        })
     }
     catch(error){
        res.status(500).json({
            message: `Failed to register the user ${error}`,
        }
        )
     }
}

export const refreshToken = async (req: Request, res: Response): Promise<any> => {
    const { refreshToken } = req.body;
  
    if (!refreshToken) {
      return res.status(401).json({ message: "Refresh token required" });
    }
  
    try {
      // Verify refresh token
      const decoded: any = jwt.verify(refreshToken, JWT_REFRESH_SECRET!);
  
      if (!decoded.id) {
        return res.status(401).json({ message: "Invalid refresh token" });
      }
  
      // Generate a new access token
      const newAccessToken = jwt.sign({ id: decoded.id }, JWT_SECRET!, { expiresIn: "10h" });
  
      res.json({ accessToken: newAccessToken });
    } catch (error) {
      res.status(403).json({ message: "Invalid or expired refresh token" });
    }
  };

export const login = async(req:Request, res: Response):Promise<any>=>{

     const {email,password,fcmToken} = req.body;
     try{
        const result = await pool.query(
            'SELECT * FROM users WHERE email = $1',
            [email]
        );

        const user = result.rows[0];
        if (!user) {
            return res.status(404).json({
                message: "User not found",
            });
        }

        

        const isMatch = await bcrypt.compare(password, user.password);
        if (isMatch) {
            //Save fcm token
           if(fcmToken){
            await pool.query(
              'UPDATE users SET fcm_token = $1 WHERE id = $2',
              [fcmToken, user.id]
          )
        }
      
            const token = jwt.sign({ id: user.id }, JWT_SECRET!,{expiresIn: '30d'});
            const refreshToken = jwt.sign({ id: user.id }, JWT_REFRESH_SECRET!, { expiresIn: "7d" });
            const finalResult = {
                user: {
                  id: user.id,
                  username: user.username,
                  email: user.email,
                  created_at: user.created_at,
                  updated_at: user.updated_at,
                  token: token,
                  refreshToken: refreshToken
                },
                
               
              };
        
               // Add user to active users list in Redis
               
               res.status(200).json(finalResult); // Send the correct structure

               await pool.query(
                "INSERT INTO active_users (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING",
                [user.id]
              );
        } else {
            res.status(500).json({
                message: "Invalid credentials",
            });
        }


            
        }
     catch(error){
         res.status(500).json({
            message: `Failed to login the user ${error}`,
        }
        )
     }

}

export const logout = async (req: Request, res: Response) => {
  const { userId } = req.body;

  await pool.query("DELETE FROM active_users WHERE user_id = $1", [userId]);

  res.status(200).json({ message: "User logged out successfully" });
};
