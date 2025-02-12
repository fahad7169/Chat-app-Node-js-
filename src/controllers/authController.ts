import { Request, Response } from "express";
import pool from "../models/db";
import bcrypt from 'bcrypt'
import jwt from 'jsonwebtoken'

const SALT_ROUNDS= 10;
const JWT_SECRET = process.env.JWT_SECRET || 'fahadsecretKey';

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

export const login = async(req:Request, res: Response):Promise<any>=>{

     const {email,password} = req.body;
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
            const token = jwt.sign({ id: user.id }, JWT_SECRET,{expiresIn: '10h'});
            const finalResult = {...user,token};
            res.status(200).json({
               user: finalResult
            });
        } else {
            res.status(400).json({
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