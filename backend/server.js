const express = require("express");
const cors = require("cors");
const multer = require("multer");
const { v4: uuidv4 } = require("uuid");
const path = require("path");
const fs = require("fs");
const { Pool } = require("pg");
const AWS = require("aws-sdk");
require("dotenv").config();

// Configure AWS S3
const s3 = new AWS.S3({
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    region: process.env.AWS_REGION || 'us-east-1',
    signatureVersion: 'v4'
});

const S3_BUCKET_NAME = process.env.S3_BUCKET_NAME || 'quicksend-files';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// File storage
const uploadsDir = path.join(__dirname, "uploads");
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// Initialize database table
async function initializeDatabase() {
    try {
        // First, create the table if it doesn't exist
        const createTableQuery = `
            CREATE TABLE IF NOT EXISTS files (
                id UUID PRIMARY KEY,
                original_name TEXT NOT NULL,
                size BIGINT NOT NULL,
                upload_date TIMESTAMPTZ NOT NULL,
                expires_at TIMESTAMPTZ NOT NULL,
                download_count INTEGER NOT NULL DEFAULT 0,
                is_active BOOLEAN NOT NULL DEFAULT TRUE
            );
        `;
        await pool.query(createTableQuery);
        
        // Check if s3_key column exists, if not add it
        try {
            await pool.query('SELECT s3_key FROM files LIMIT 1');
            console.log('s3_key column already exists');
        } catch (error) {
            if (error.code === '42703') { // Column doesn't exist
                console.log('Adding s3_key column to files table');
                await pool.query('ALTER TABLE files ADD COLUMN s3_key TEXT');
            }
        }
        
        // Check if s3_bucket column exists, if not add it
        try {
            await pool.query('SELECT s3_bucket FROM files LIMIT 1');
            console.log('s3_bucket column already exists');
        } catch (error) {
            if (error.code === '42703') { // Column doesn't exist
                console.log('Adding s3_bucket column to files table');
                await pool.query('ALTER TABLE files ADD COLUMN s3_bucket TEXT');
            }
        }
        
        console.log('Database table initialized successfully');
    } catch (error) {
        console.error('Error initializing database:', error);
    }
}

// Health check endpoint
app.get("/health", async (req, res) => {
    try {
        const result = await pool.query('SELECT COUNT(*) as count FROM files WHERE is_active = true');
        const fileCount = parseInt(result.rows[0].count);
        
        // Get memory usage
        const memUsage = process.memoryUsage();
        const memUsageMB = {
            rss: Math.round(memUsage.rss / 1024 / 1024),
            heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
            heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
            external: Math.round(memUsage.external / 1024 / 1024)
        };
        
        res.json({ 
            status: "healthy", 
            timestamp: new Date().toISOString(),
            files: fileCount,
            memory: memUsageMB,
            uptime: process.uptime()
        });
    } catch (error) {
        console.error('Health check error:', error);
        res.status(500).json({ 
            status: "unhealthy", 
            error: "Database connection failed" 
        });
    }
});

// File upload endpoint with streaming for large files
app.post("/upload", multer({ 
    dest: uploadsDir,
    limits: {
        fileSize: 5 * 1024 * 1024 * 1024, // 5GB max
        fieldSize: 10 * 1024 * 1024 // 10MB for form fields
    }
}).single("file"), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: "No file uploaded" });
        }

        const fileId = uuidv4();
        const uploadDate = new Date();
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

        console.log(`Uploading file: ${req.file.originalname}`);
        console.log(`File saved to: ${req.file.path}`);
        console.log(`File size: ${req.file.size}`);
        console.log(`Generated fileId: ${fileId}`);

        // Upload to AWS S3 with streaming for large files
        const s3Key = `files/${fileId}/${req.file.originalname}`;
        let s3Result;
        try {
            const uploadParams = {
                Bucket: S3_BUCKET_NAME,
                Key: s3Key,
                Body: fs.createReadStream(req.file.path), // Stream instead of loading into memory
                ContentType: req.file.mimetype || 'application/octet-stream',
                Metadata: {
                    originalName: req.file.originalname,
                    fileId: fileId
                }
            };
            
            s3Result = await s3.upload(uploadParams).promise();
            console.log(`File uploaded to S3: ${s3Result.Location}`);
        } catch (s3Error) {
            console.error("S3 upload error:", s3Error);
            return res.status(500).json({ error: "Failed to upload file to S3" });
        }

        // Insert file metadata into database
        const insertQuery = `
            INSERT INTO files (id, original_name, size, upload_date, expires_at, download_count, is_active, s3_key, s3_bucket)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        `;
        
        await pool.query(insertQuery, [
            fileId,
            req.file.originalname,
            req.file.size,
            uploadDate,
            expiresAt,
            0,
            true,
            s3Key,
            S3_BUCKET_NAME
        ]);

        const downloadLink = `https://api.quicksend.vip/download/${fileId}`;
        
        console.log(`Generated download link: ${downloadLink} - Using api.quicksend.vip domain`);
        
        res.json({
            success: true,
            fileId: fileId,
            downloadLink: downloadLink,
            fileName: req.file.originalname,
            fileSize: req.file.size,
            expiresAt: expiresAt.toISOString()
        });
    } catch (error) {
        console.error("Upload error:", error);
        res.status(500).json({ error: "Upload failed" });
    }
});

// File download endpoint
app.get("/download/:fileId", async (req, res) => {
    try {
        const fileId = req.params.fileId;
        
        console.log(`Download request for fileId: ${fileId}`);
        
        // Get file data from database
        const result = await pool.query('SELECT * FROM files WHERE id = $1', [fileId]);
        
        if (result.rows.length === 0) {
            console.log(`File not found in database: ${fileId}`);
            return res.status(404).json({ error: "File not found" });
        }
        
        const fileData = result.rows[0];
        console.log(`File found in database: ${fileData.original_name}`);
        
        if (!fileData.is_active) {
            console.log(`File is inactive: ${fileId}`);
            return res.status(404).json({ error: "File not found" });
        }

        if (new Date() > new Date(fileData.expires_at)) {
            console.log(`File has expired: ${fileId}`);
            // Mark file as inactive
            await pool.query('UPDATE files SET is_active = false WHERE id = $1', [fileId]);
            return res.status(410).json({ error: "File has expired" });
        }

        // Increment download count
        await pool.query('UPDATE files SET download_count = download_count + 1 WHERE id = $1', [fileId]);
        
        // Generate S3 presigned URL for download
        if (fileData.s3_key && fileData.s3_bucket) {
            try {
                const params = {
                    Bucket: fileData.s3_bucket,
                    Key: fileData.s3_key,
                    Expires: 3600, // URL expires in 1 hour
                    ResponseContentDisposition: `attachment; filename="${fileData.original_name}"`
                };
                
                const presignedUrl = await s3.getSignedUrlPromise('getObject', params);
                console.log(`Generated presigned URL for file: ${fileId}`);
                res.redirect(presignedUrl);
            } catch (s3Error) {
                console.error("Error generating presigned URL:", s3Error);
                res.status(500).json({ error: "Failed to generate download link" });
            }
        } else {
            console.log(`No S3 key found for file: ${fileId}`);
            res.status(404).json({ error: "File not found" });
        }
    } catch (error) {
        console.error("Download error:", error);
        res.status(500).json({ error: "Download failed" });
    }
});

// List files endpoint
app.get("/files", async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM files WHERE is_active = true ORDER BY upload_date DESC');
        
        const files = result.rows.map(row => ({
            id: row.id,
            name: row.original_name,
            size: row.size,
            uploadDate: row.upload_date,
            fileName: row.original_name,
            fileSize: row.size,
            expiresAt: row.expires_at,
            downloadCount: row.download_count,
            s3Key: row.s3_key,
            s3Bucket: row.s3_bucket
        }));
        
        // Calculate total storage used
        const totalSize = files.reduce((sum, file) => sum + parseInt(file.size), 0);
        const totalSizeGB = (totalSize / (1024 * 1024 * 1024)).toFixed(2);
        
        res.json({
            files: files,
            totalFiles: files.length,
            totalSizeBytes: totalSize,
            totalSizeGB: totalSizeGB
        });
    } catch (error) {
        console.error("Files list error:", error);
        res.status(500).json({ error: "Error listing files" });
    }
});

// Storage usage endpoint
app.get("/storage", async (req, res) => {
    try {
        const result = await pool.query('SELECT SUM(size) as total_size, COUNT(*) as file_count FROM files WHERE is_active = true');
        const totalSize = parseInt(result.rows[0].total_size) || 0;
        const fileCount = parseInt(result.rows[0].file_count) || 0;
        
        const totalSizeGB = (totalSize / (1024 * 1024 * 1024)).toFixed(2);
        const totalSizeMB = (totalSize / (1024 * 1024)).toFixed(2);
        
        res.json({
            totalFiles: fileCount,
            totalSizeBytes: totalSize,
            totalSizeMB: totalSizeMB,
            totalSizeGB: totalSizeGB,
            lastUpdated: new Date().toISOString()
        });
    } catch (error) {
        console.error("Storage usage error:", error);
        res.status(500).json({ error: "Error getting storage usage" });
    }
});

// Start server
app.listen(PORT, "0.0.0.0", async () => {
    console.log(`QuickSend API server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
    console.log(`Upload endpoint: /upload`);
    console.log(`Download endpoint: /download/:fileId`);
    console.log(`Health check: /health`);
    
    // Initialize database
    await initializeDatabase();
    
    console.log(`Database connected and initialized`);
});

module.exports = app;
