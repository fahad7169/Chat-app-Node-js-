import { Request, Response } from "express";
import pool from "../models/db";


export const fetchAllMessagesByConversationId =async (req: Request, res: Response) => {
   
    const {conversationId} = req.params; //

    
    try {

        const result = await pool.query(
            `
            SELECT m.id, m.content, m.sender_id, m.conversation_id, m.created_at, m.status
            from messages m
            WHERE m.conversation_id = $1
            Order by m.created_at ASC;
            `,
            [conversationId]
        )

        res.json(result.rows);

        

        
    } catch (error) {
        res.status(500).json({error: "Failed to fetch messages"});
    }

}

export const saveMessage =async (conversationId: string, senderId: string, content: string) => {  
    try {
        // In your message controller:
if (!conversationId || !senderId || !content) {
    throw new Error("Missing required fields");
  }

        const result = await pool.query(
            `
            INSERT INTO messages (conversation_id, sender_id, content) VALUES ($1, $2, $3)
            RETURNING *;
            `,
            [conversationId, senderId, content]
        )

      return result.rows[0];

        
    } catch (error) {
       throw new Error("Failed to save message");
    }
}

export const deleteMessages = async (req: Request, res: Response): Promise<any> => {
    const messageIds = req.body.messageIds;

    if (!Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({ error: 'No message IDs provided' });
    }
  
    try {
      // Create a SQL query to delete messages
      const query = {
        text: 'DELETE FROM messages WHERE id = ANY($1) RETURNING id',
        values: [messageIds],
      };
      
  
      // Execute the query
      const result = await pool.query(query);
  
      if (result.rows.length > 0) {
        return res.status(200).json({ message: 'Messages deleted successfully' });
      } else {
        return res.status(404).json({ error: 'No messages found with the given IDs' });
      }
    } catch (error) {
    
      return res.status(500).json({ error: 'Internal Server Error' });
    }

}