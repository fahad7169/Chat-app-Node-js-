import pool from "../models/db";
import { Request, Response } from "express";

export const fetchAllConversationsByUserId =async (req: Request, res: Response) => {
    let userId = null;
    if(req.user){
        userId = req.user.id;
    }


    try {
        const result = await pool.query(
            `
            SELECT 
              c.id AS conversation_id,
              CASE 
                WHEN u1.id = $1 THEN u2.username
                ELSE u1.username
              END AS participant_name,
              m.content AS last_message,
              m.status AS last_message_status, -- ✅ Added status field
              m.created_at AS last_message_time
            FROM conversations c
            JOIN users u1 ON u1.id = c.participant_one
            JOIN users u2 ON u2.id = c.participant_two
            LEFT JOIN LATERAL (
              SELECT content, status, created_at  -- ✅ Selecting status
              FROM messages
              WHERE conversation_id = c.id
              ORDER BY created_at DESC
              LIMIT 1
            ) m ON true
            WHERE c.participant_one = $1 OR c.participant_two = $1
            ORDER BY m.created_at DESC;
            `,
            [userId]
          );
          


        res.status(200).json({
            conversations: result.rows
        })
    } 
    catch (error) {
        res.status(500).json({
            message: `Failed to get conversations ${error}`
        })
    }
}


export const checkOnCreateConversation =async (req: Request, res: Response):Promise<any> =>{
    let userId = null;
    if(req.user){
        userId = req.user.id;
    }

    console.log("Request for conversation received")

    const { contactId } = req.body;
    
    try {
        const existingConversation = await pool.query(
            `
            SELECT id FROM conversations
            Where (participant_one = $1 AND participant_two = $2) OR (participant_one = $2 AND participant_two = $1)
            Limit 1;
            `,
            [userId, contactId]
        )

        if (existingConversation.rowCount !=null && existingConversation.rowCount! > 0) {
            return res.json({conversationId: existingConversation.rows[0].id})
        }

        const newConversation = await pool.query(
            `
            INSERT INTO conversations (participant_one,participant_two)
            VALUES($1 , $2)
            RETURNING id;
            `,
            [userId,contactId]
        )

        res.json({conversationId: newConversation.rows[0].id})
    } catch (error) {
        console.error("Error checking or creating conversation: " ,error);
        res.status(500).json(error)
    }
}