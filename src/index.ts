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


io.on('connection', (socket) => {
  console.log('a user connected',socket.id);

  //user 1
  //user 2


    // User joins chat
    socket.on("joinConversation", ({ userId, conversationId }) => {
      console.log(`${userId} joined conversation ${conversationId}`);
      socket.join(conversationId);
    
    });

  socket.on('sendMessage', async (data) => {
    const { conversationId, senderId, content } = data;
    try {
        const message = await saveMessage(conversationId, senderId, content)
console.log("Message: ")
console.log(message);
        io.to(conversationId).emit('receiveMessage', message);
        console.log("Message emitted to receiver",message.content)

        io.emit('conversationUpdated',{
          conversationId,
          lastMessageId: message.id,
          lastMessage: message.content,
          lastMessageTime: message.created_at,
          lastMessageStatus: message.status,

        
})

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

const getUserFromDB = async (userid:string) => {

  console.log("Fetching username for user id: " ,userid)
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [userid]) 
    return result.rows[0];
}

const PORT = process.env.PORT || 6000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));