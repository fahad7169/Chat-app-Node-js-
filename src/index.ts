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

const serviceAccount = require("../serviceAccountKey.json"); // Use require() instead of import


// Initialize Firebase Admin SDK
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


app.use(json());

app.use("/auth", authRoutes);
app.use("/conversations", coversationRoutes);
app.use("/messages", messagesRoutes);
app.use("/contacts", contactsRoutes);


const onlineUsers = new Map(); // Store userId -> username
const loggedInUsers = new Set<string>(); // Stores user IDs of logged-in users

export { loggedInUsers };


io.on('connection', (socket) => {
  console.log('a user connected',socket.id);

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
          console.log(`${userId} joined conversation ${conversationId}`);
          socket.join(conversationId);
        } else {
          console.log(`${userId} is already in conversation ${conversationId}`);
        }
      }
    } catch (error) {
      console.error("Error fetching conversations:", error);
    }
  });
  


  socket.on('sendMessage', async (data) => {
    const { conversationId, senderId, content } = data;
    try {
        const message = await saveMessage(conversationId, senderId, content)
console.log("Message: ")
console.log(message);
io.to(conversationId).emit("updatedMessage", message)
        io.to(conversationId).emit('receiveMessage', message);
        console.log("Message emitted to receiver",message.content)



        const participantName = await getParticipantName(senderId, conversationId);

        io.emit('conversationUpdated',{
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

    console.log("Body: ",body)

    await sendNotification(body);
   


    } catch (error) {
        console.error("Failed to save message:", error);
    }
  });

  socket.on('disconnect', () => {

    console.log("User disconnected: " + socket.id);

    const user = onlineUsers.get(socket.id);
    if (user) {
      console.log(`${user.username} (${user.userId}) disconnected`);
      io.emit("userOffline", { userId: user.userId, username: user.username });
      onlineUsers.delete(socket.id);
    }
 
  })

  // User starts typing
  socket.on("typing", ({ conversationId, userId }) => {
    console.log(`${userId} is typing in conversation ${conversationId}`);
    socket.to(conversationId).emit('typing', {conversationId, userId});
  })


  // User stops typing
  socket.on("stopTyping", ({ conversationId, userId }) => {
    console.log(`${userId} stopped typing in conversation ${conversationId}`);
    socket.to(conversationId).emit('stopTyping', {conversationId, userId});
  })

  socket.on("userOnline", async ({ userId }) => {
    console.log("User online event received for userid: ", userId);
    if (!userId) return;
    const user = await getUserFromDB(userId); // Fetch username from DB
    if (!user) return;

    console.log(`${user.username} (${userId}) is online`);

    onlineUsers.set(socket.id, { userId, username: user.username }); // Store details

    io.emit("userOnline", { userId, username: user.username });
  });


  socket.on("userOffline", ({ userId }) => {
    if (!userId) return;

    const user = onlineUsers.get(socket.id);
    if (user) {
      console.log(`${user.username} (${userId}) is offline`);
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
        console.log("Received undefined messageId or conversationId:", data);
        return;
    }
    
    console.log(`Message ${messageId} delivered`);
    //update the message status to delivered in the database
    socket.to(conversationId).emit("messageStatusUpdated",{ messageId,conversationId, status: "delivered" })
    console.log("Message status sent to receiver");
    await updateMessageStatus(messageId, "delivered");
    console.log("Status updated in database")
  });

    // Handle Message Seen
    socket.on("messageSeen", async(data) => {
      
      const { messageId, conversationId } = data; // ✅ Properly extract messageId & conversationId
      console.log(`Message ${messageId} seen`);



      //Update the message status to seen in the database
     await updateMessageStatus(messageId, "seen");
     socket.to(conversationId).emit("messageStatusUpdated",{ messageId,conversationId, status: "seen" })
    });
  

})


app.get("/", (req, res) => {
    console.log("hello");
    res.send("yes it works");
})

const updateMessageStatus = async(messageId: string, status: string) => {
    //update the message status  in the database

    await pool.query('UPDATE messages SET status = $1 WHERE id = $2', [status, messageId]);
    console.log("Message status updated to ", status, " for message ", messageId);


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
  console.log("Sending notification to receiver with token: ", receiverToken);

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
    console.log("Error sending notification",e)
  }
 
};

const getUserFromDB = async (userid:string) => {

  console.log("Fetching username for user id: " ,userid)
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
    console.error("Error fetching participant name:", error);
    throw error;
  }
};

app.post("/messages/delivered", async (req, res) => {
  
  const { messageId, conversationId } = req.body;

  console.log("Received messageId: ",messageId)
  console.log("Received conversationId: ",conversationId)

  try {
    await updateMessageStatus(messageId, "delivered");
  io.to(conversationId).emit("messageStatusUpdated",{ messageId,conversationId, status: "delivered" })
   
  } catch (error) {
    console.error("Error updating message status:", error);
    res.status(500).json({ message: "Failed to update message status" });
  }
});

const isUserLoggedIn = async (userId: string): Promise<boolean> => {
  try {
    const result = await pool.query(
      "SELECT EXISTS (SELECT 1 FROM active_users WHERE user_id = $1)",
      [userId]
    );
    return result.rows[0].exists;
  } catch (err) {
    console.error("Error checking user login status:", err);
    return false;
  }
};





const PORT = process.env.PORT || 6000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));