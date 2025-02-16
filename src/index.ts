import express from "express";
import { json } from "body-parser";
import authRoutes from "./routes/authRoutes";
import coversationRoutes from "./routes/conversationRoutes";
import messagesRoutes from "./routes/messagesRoutes";
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

io.on('connection', (socket) => {
  console.log('a user connected',socket.id);

  //user 1
  //user 2


  socket.on('joinConversation', (conversationId) => {
    socket.join(conversationId);
    console.log(`user joined conversation ${conversationId}`);
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
    console.log('user disconnected',socket.id);
  })

})


app.get("/", (req, res) => {
    console.log("hello");
    res.send("yes it works");
})

const PORT = process.env.PORT || 6000;
server.listen(PORT, () => console.log(`Server running on port ${PORT}`));