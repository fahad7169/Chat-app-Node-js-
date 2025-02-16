import { Router } from "express";
import { verifyToken } from "../middlewares/authMiddleware";
import { fetchAllMessagesByConversationId } from "../controllers/messagesController";



const router = Router();

router.get('/:conversationId',verifyToken, fetchAllMessagesByConversationId)

export default router;