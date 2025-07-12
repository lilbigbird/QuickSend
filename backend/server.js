const express = require("express");
const cors = require("cors");
const multer = require("multer");
const { v4: uuidv4 } = require("uuid");
const path = require("path");
const fs = require("fs");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// File storage
const uploadsDir = path.join(__dirname, "uploads");
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// In-memory file database (for demo purposes)
const fileDatabase = new Map();

// Health check endpoint
app.get("/health", (req, res) => {
    res.json({ 
        status: "healthy", 
        timestamp: new Date().toISOString(),
        files: fileDatabase.size
    });
});

// File upload endpoint
app.post("/upload", multer({ dest: uploadsDir }).single("file"), (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: "No file uploaded" });
        }

        const fileId = uuidv4();
        const fileData = {
            id: fileId,
            originalName: req.file.originalname,
            size: req.file.size,
            uploadDate: new Date(),
            expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
            downloadCount: 0,
            isActive: true
        };

        fileDatabase.set(fileId, fileData);

        const downloadLink = `${req.protocol}://${req.get("host")}/download/${fileId}`;
        
        res.json({
            success: true,
            fileId: fileId,
            downloadLink: downloadLink,
            fileName: fileData.originalName,
            fileSize: fileData.size,
            expiresAt: fileData.expiresAt.toISOString()
        });
    } catch (error) {
        console.error("Upload error:", error);
        res.status(500).json({ error: "Upload failed" });
    }
});

// File download endpoint
app.get("/download/:fileId", (req, res) => {
    try {
        const fileId = req.params.fileId;
        const fileData = fileDatabase.get(fileId);

        if (!fileData || !fileData.isActive) {
            return res.status(404).json({ error: "File not found" });
        }

        if (new Date() > fileData.expiresAt) {
            fileData.isActive = false;
            return res.status(410).json({ error: "File has expired" });
        }

        const filePath = path.join(uploadsDir, fileId);
        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: "File not found" });
        }

        fileData.downloadCount++;
        res.download(filePath, fileData.originalName);
    } catch (error) {
        console.error("Download error:", error);
        res.status(500).json({ error: "Download failed" });
    }
});

// List files endpoint
app.get("/files", (req, res) => {
    try {
        const files = [];
        for (const [fileId, fileData] of fileDatabase) {
            if (fileData.isActive) {
                files.push({
                    id: fileId,
                    name: fileData.originalName,
                    size: fileData.size,
                    uploadDate: fileData.uploadDate,
                    fileName: fileData.originalName,
            fileSize: fileData.size,
            expiresAt: fileData.expiresAt.toISOString(),
                    downloadCount: fileData.downloadCount
                });
            }
        }
        res.json(files);
    } catch (error) {
        console.error("Files list error:", error);
        res.status(500).json({ error: "Error listing files" });
    }
});

// Start server
app.listen(PORT, "0.0.0.0", () => {
    console.log(`QuickSend API server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
    console.log(`Upload endpoint: /upload`);
    console.log(`Download endpoint: /download/:fileId`);
    console.log(`Health check: /health`);
    console.log(`Database loaded with ${fileDatabase.size} files`);
});

module.exports = app;
