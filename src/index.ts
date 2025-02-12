import express from "express";
import { json } from "body-parser";
import authRoutes from "./routes/authRoutes";
import coversationRoutes from "./routes/conversationRoutes";


const app = express();
app.use(json());

app.use("/auth", authRoutes);
app.use("conversations", coversationRoutes);


app.get("/", (req, res) => {
    console.log("hello");
    res.send("yes it works");
})

const PORT = process.env.PORT || 6040;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));