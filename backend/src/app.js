import express from "express";
import leadRoutes from "./routes/leadRoutes.js";
import dotenv from 'dotenv';
dotenv.config();

const app = express();
app.use(express.json());

app.use("/api/leads", leadRoutes);

// Health check
app.get("/health", (req, res) => res.json({ status: "ok" }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});