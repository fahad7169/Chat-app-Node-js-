import { Router } from "express";
import { login, register, refreshToken, logout } from "../controllers/authController";
import { verifyToken } from "../middlewares/authMiddleware";



const router = Router();

router.post('/register',register); 
router.post('/login',login);
router.post('/refresh-token',refreshToken);
router.post('/logout',logout);

router.get('/validateToken', verifyToken, (req, res) => {
    res.status(200).json({
      message: 'Token is valid',
    });
  });

export default router;