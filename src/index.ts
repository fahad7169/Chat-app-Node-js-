import express from "express";
import { json } from "body-parser";
import authRoutes from "./routes/authRoutes";
import coversationRoutes from "./routes/conversationRoutes";
import messagesRoutes from "./routes/messagesRoutes";
import contactsRoutes from "./routes/contactsRoutes";
import http from 'http'
import { Server } from "socket.io";
import { saveMessage } from "./controllers/messagesController";


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


const onlineUsers = new Map();

io.on('connection', (socket) => {
  console.log('a user connected',socket.id);

  //user 1
  //user 2


    // User joins chat
    socket.on("joinConversation", ({ userId, conversationId }) => {
      console.log(`${userId} joined conversation ${conversationId}`);
      socket.join(conversationId);
      onlineUsers.set(userId, socket.id);
    });

  socket.on('sendMessage', async (data) => {
    const { conversationId, senderId, content } = data;
    try {
        const message = await saveMessage(conversationId, senderId, content);
console.log("Message: ")
console.log(message);
        io.to(conversationId).emit('receiveMessage', message);

        io.emit('conversationUpdated',{
          conversationId,
          lastMessage: message.content,
          lastMessageTime: message.created_at
        
})

    } catch (error) {
        console.error("Failed to save message:", error);
    }
  });

  socket.on('disconnect', () => {

    console.log("User disconnected: " + socket.id);
    onlineUsers.forEach((value, key) => {
      if (value === socket.id) {
        onlineUsers.delete(key);
        io.emit("userOffline", key);
      }
    });
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



  // Handle Message Delivery
  socket.on("messageDelivered", ({ messageId }) => {
    console.log(`Message ${messageId} delivered`);
    io.emit("messageStatusUpdated", { messageId, status: "delivered" });
  });

    // Handle Message Seen
    socket.on("messageSeen", ({ messageId }) => {
      console.log(`Message ${messageId} seen`);
      io.emit("messageStatusUpdated", { messageId, status: "seen" });
    });
  

})


app.get("/", (req, res) => {
    console.log("hello");
    res.send("yes it works");
})

const PORT = process.env.PORT || 6000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));