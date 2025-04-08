import { Router } from "express";
import { verifyToken } from "../middlewares/authMiddleware";
import { deleteMessages, fetchAllMessagesByConversationId } from "../controllers/messagesController";



const router = Router();

router.get('/:conversationId',verifyToken, fetchAllMessagesByConversationId)
router.post('/deleteMessages',verifyToken,deleteMessages)

export default router;