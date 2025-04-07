import express from "express";
import { json } from "body-parser";
import authRoutes from "./routes/authRoutes";
import coversationRoutes from "./routes/conversationRoutes";
import messagesRoutes from "./routes/messagesRoutes";
import contactsRoutes from "./routes/contactsRoutes";
import http from 'http'
import { Server } from "socket.io";
import { saveMessage } from "./controllers/messagesController";
import pool from "./models/db";
import admin from "firebase-admin";
import rateLimit from "express-rate-limit";

// Decode base64 string from .env
const base64Key = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
const jsonString = Buffer.from(base64Key!, 'base64').toString('utf-8');
const serviceAccount = JSON.parse(jsonString);

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const app = express();


const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"],
        allowedHeaders: ["Authorization"],
        credentials: true
    }
});
// Limit each IP to 100 requests per 15 minutes
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    status: 429,
    message: "Too many requests from this IP, please try again later.",
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});


app.use(json());

app.use("/auth", limiter, authRoutes);
app.use("/conversations", limiter, coversationRoutes);
app.use("/messages", limiter, messagesRoutes);
app.use("/contacts", limiter, contactsRoutes);



const onlineUsers = new Map(); // Store userId -> username


io.on('connection', (socket) => {

  //user 1
  //user 2
  // User joins chat
  socket.on("joinConversation", async ({ userId }) => {
    try {
      // Fetch only conversation IDs by userId
      const result = await pool.query(
        `SELECT c.id AS conversation_id
        FROM conversations c
        WHERE c.participant_one = $1 OR c.participant_two = $1;`,
        [userId]
      );
  
      // Join the user to all their conversation rooms
      for (const conversation of result.rows) {
        const conversationId = conversation.conversation_id;
  
        // Check if the user is already in this conversation room
        if (!socket.rooms.has(conversationId)) {
         
          socket.join(conversationId);
        } else {
        }
      }
    } catch (error) {
    }
  });
  


  socket.on('sendMessage', async (data) => {
    const { conversationId, senderId, content } = data;
    try {
        const message = await saveMessage(conversationId, senderId, content)
io.to(conversationId).emit("updatedMessage", message)
        io.to(conversationId).emit('receiveMessage', message);



        const participantName = await getParticipantName(senderId, conversationId);

        io.to(conversationId).emit('conversationUpdated',{
          conversationId,
          lastMessageId: message.id,
          senderId: senderId,
          participantName: participantName,
          lastMessage: message.content,
          lastMessageTime: message.created_at,
          lastMessageStatus: message.status,

        
})

const result = await pool.query(
  `SELECT 
      CASE 
          WHEN participant_one = $1 THEN participant_two
          ELSE participant_one
      END AS receiverId
   FROM conversations
   WHERE (participant_one = $1 OR participant_two = $1)
     AND id = $2`,
  [senderId, conversationId]  // Add the conversationId to the query parameters
);

const receiverId = result.rows[0]?.receiverid;

const result2 = await pool.query(
  `SELECT username from users WHERE id = $1`,
  [senderId]
);

const senderName = result2.rows[0]?.username;

    const body = {
      messageId: message.id,
      conversationId:conversationId,
      senderId: senderId,
      participantName: participantName,
      content: message.content,
      created_at: message.created_at,
      status: message.status,
     receiverId: receiverId,
     senderName: senderName
    }


    await sendNotification(body);
   


    } catch (error) {
    }
  });

  socket.on('disconnect', () => {


    const user = onlineUsers.get(socket.id);
    if (user) {
      io.emit("userOffline", { userId: user.userId, username: user.username });
      onlineUsers.delete(socket.id);
    }
 
  })

  // User starts typing
  socket.on("typing", ({ conversationId, userId }) => {
    socket.to(conversationId).emit('typing', {conversationId, userId});
  })


  // User stops typing
  socket.on("stopTyping", ({ conversationId, userId }) => {
    socket.to(conversationId).emit('stopTyping', {conversationId, userId});
  })

  socket.on("userOnline", async ({ userId }) => {
    if (!userId) return;
    const user = await getUserFromDB(userId); // Fetch username from DB
    if (!user) return;


    onlineUsers.set(socket.id, { userId, username: user.username }); // Store details

    io.emit("userOnline", { userId, username: user.username });
  });


  socket.on("userOffline", ({ userId }) => {
    if (!userId) return;

    const user = onlineUsers.get(socket.id);
    if (user) {
      io.emit("userOffline", { userId, username: user.username });
      onlineUsers.delete(socket.id);
    }
  });

    // Send online users list when requested
    socket.on("getOnlineUsers", () => {
      const onlineUsersList = Array.from(onlineUsers.values());
      socket.emit("onlineUsersList", onlineUsersList);
    });


  // Handle Message Delivery
  socket.on("messageDelivered", async(data) => {
    const { messageId, conversationId } = data; // ✅ Properly extract messageId & conversationId
    if (!messageId || !conversationId) {
        return;
    }
    
    //update the message status to delivered in the database
    socket.to(conversationId).emit("messageStatusUpdated",{ messageId,conversationId, status: "delivered" })
    await updateMessageStatus(messageId, "delivered");
  });

    // Handle Message Seen
    socket.on("messageSeen", async(data) => {
      
      const { messageId, conversationId } = data; // ✅ Properly extract messageId & conversationId



      //Update the message status to seen in the database
     await updateMessageStatus(messageId, "seen");
     socket.to(conversationId).emit("messageStatusUpdated",{ messageId,conversationId, status: "seen" })
    });
  

})




const updateMessageStatus = async(messageId: string, status: string) => {
    //update the message status  in the database

    await pool.query('UPDATE messages SET status = $1 WHERE id = $2', [status, messageId]);


}


const sendNotification = async (body: any) => {
  const isLoggedIn = await isUserLoggedIn(body.receiverId);
  if(!isLoggedIn){
    return;
  }

  try{
 // Get receiver's FCM token from database
 const receiverResult = await pool.query(
  "SELECT fcm_token FROM users WHERE id = $1",
  [body.receiverId]
);
const receiverToken = receiverResult.rows[0]?.fcm_token;


if (receiverToken) {

  // Send FCM Notification
  await admin.messaging().send({
    token: receiverToken,
    notification: {
      title: body.senderName,
      body: body.content,
    },
    data: {
      conversationId: String(body.conversationId),
      messageId: String(body.messageId),
      senderId: String(body.senderId),
      created_at: new Date(body.created_at).toISOString(), // ✅ Ensures strict format
      status: String(body.status),
      content: String(body.content),
      senderName: String(body.senderName),
    },
  });
}
  }
  catch(e){
  }
 
};

const getUserFromDB = async (userid:string) => {

    const result = await pool.query('SELECT * FROM users WHERE id = $1', [userid]) 
    return result.rows[0];
}

const getParticipantName = async (userId: string, conversationId: string) => {
  const query = `
    SELECT 
      CASE 
        WHEN c.participant_one = $1 THEN u2.username
        ELSE u1.username
      END AS participant_name
    FROM conversations c
    JOIN users u1 ON u1.id = c.participant_one
    JOIN users u2 ON u2.id = c.participant_two
    WHERE c.id = $2;
  `;

  try {
    const result = await pool.query(query, [userId, conversationId]);
    return result.rows[0]?.participant_name || null;
  } catch (error) {
    throw error;
  }
};



const isUserLoggedIn = async (userId: string): Promise<boolean> => {
  try {
    const result = await pool.query(
      "SELECT EXISTS (SELECT 1 FROM active_users WHERE user_id = $1)",
      [userId]
    );
    return result.rows[0].exists;
  } catch (err) {
    return false;
  }
};





const PORT = process.env.PORT || 6000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));