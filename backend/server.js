const express = require("express");
const cors = require("cors");
const multer = require("multer");
const { v4: uuidv4 } = require("uuid");
const path = require("path");
const fs = require("fs");
const { Pool } = require("pg");
const AWS = require("aws-sdk");
const rateLimit = require("express-rate-limit");
const cluster = require("cluster");
const os = require("os");
const Redis = require("redis");
const compression = require("compression");
const helmet = require("helmet");
const auth = require("./auth");
require("dotenv").config();

// Clustering for multi-core utilization
if (cluster.isMaster) {
    const numCPUs = os.cpus().length;
    console.log(`Master ${process.pid} is running`);
    console.log(`Starting ${numCPUs} workers...`);
    
    // Fork workers
    for (let i = 0; i < numCPUs; i++) {
        cluster.fork();
    }
    
    cluster.on('exit', (worker, code, signal) => {
        console.log(`Worker ${worker.process.pid} died`);
        // Replace the dead worker
        cluster.fork();
    });
    
    // Monitor cluster health
    setInterval(() => {
        const workers = Object.keys(cluster.workers);
        console.log(`Active workers: ${workers.length}`);
    }, 30000);
    
    return;
}

// Worker process code
console.log(`Worker ${process.pid} started`);

// Configure AWS S3 with optimized settings for high concurrency
let s3;
try {
    s3 = new AWS.S3({
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
        region: process.env.AWS_REGION || 'us-east-1',
        signatureVersion: 'v4',
        httpOptions: {
            timeout: 300000, // 5 minutes
            connectTimeout: 60000, // 1 minute
            maxRetries: 3,
            agent: false // Disable keep-alive for better concurrency
        },
        maxRetries: 3,
        retryDelayOptions: {
            base: 300 // Base delay for retries
        }
    });
} catch (error) {
    console.error('Error initializing S3:', error);
    s3 = null;
}

// S3 upload configuration for better concurrency
const s3UploadConfig = {
    partSize: 10 * 1024 * 1024, // 10MB parts for multipart uploads
    queueSize: 4, // Number of parts to upload concurrently
    leavePartsOnError: false
};

const S3_BUCKET_NAME = process.env.S3_BUCKET_NAME || 'quicksend-files';

// Redis client for caching and session management
const redisClient = Redis.createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379',
    retry_strategy: function(options) {
        if (options.error && options.error.code === 'ECONNREFUSED') {
            return new Error('The server refused the connection');
        }
        if (options.total_retry_time > 1000 * 60 * 60) {
            return new Error('Retry time exhausted');
        }
        if (options.attempt > 10) {
            return undefined;
        }
        return Math.min(options.attempt * 100, 3000);
    }
});

redisClient.on('error', (err) => {
    console.error('Redis Client Error:', err);
});

redisClient.on('connect', () => {
    console.log('Redis Client Connected');
});

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet({
    contentSecurityPolicy: false, // Disable for API
    crossOriginEmbedderPolicy: false
}));

// Compression middleware
app.use(compression());

// Enhanced rate limiting for high concurrency
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Increased from 50 to 100
    message: { error: 'Too many authentication attempts, please try again later' },
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: true
});

const uploadLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 200, // Increased from 100 to 200
    message: { error: 'Too many uploads, please try again later' },
    standardHeaders: true,
    legacyHeaders: false
});

// General API rate limiting with higher limits
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 2000, // Increased from 1000 to 2000
    message: { error: 'Too many requests, please try again later' },
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: true
});

// Middleware
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : '*',
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Enhanced database connection pool for high concurrency
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    max: 50, // Increased from 20 to 50
    min: 10, // Minimum connections
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000, // Reduced from 2000 to 5000
    acquireTimeoutMillis: 10000,
    reapIntervalMillis: 1000,
    createTimeoutMillis: 10000,
    destroyTimeoutMillis: 5000,
    createRetryIntervalMillis: 200,
    propagateCreateError: false
});

// Database connection monitoring
pool.on('connect', (client) => {
    console.log('New database client connected');
});

pool.on('error', (err, client) => {
    console.error('Unexpected error on idle client', err);
});

// File storage with cleanup
const uploadsDir = path.join(__dirname, "uploads");
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// Cleanup old temporary files every hour
setInterval(() => {
    fs.readdir(uploadsDir, (err, files) => {
        if (err) return;
        
        const now = Date.now();
        files.forEach(file => {
            const filePath = path.join(uploadsDir, file);
            fs.stat(filePath, (err, stats) => {
                if (err) return;
                
                // Delete files older than 1 hour
                if (now - stats.mtime.getTime() > 60 * 60 * 1000) {
                    fs.unlink(filePath, () => {});
                }
            });
        });
    });
}, 60 * 60 * 1000);

// Initialize database tables
async function initializeDatabase() {
    try {
        // Initialize users table
        await auth.initializeUsersTable();
        
        // Create files table with optimized indexes
        const createTableQuery = `
            CREATE TABLE IF NOT EXISTS files (
                id UUID PRIMARY KEY,
                original_name TEXT NOT NULL,
                size BIGINT NOT NULL,
                upload_date TIMESTAMPTZ NOT NULL,
                expires_at TIMESTAMPTZ NOT NULL,
                download_count INTEGER NOT NULL DEFAULT 0,
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                s3_key TEXT,
                s3_bucket TEXT,
                user_id UUID REFERENCES users(id),
                created_at TIMESTAMPTZ DEFAULT NOW(),
                status VARCHAR(50) NOT NULL DEFAULT 'pending'
            );
        `;
        await pool.query(createTableQuery);
        
        // Add missing columns if they don't exist (migration)
        try {
            await pool.query('ALTER TABLE files ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id)');
        } catch (error) {
            console.log('user_id column already exists or error adding it:', error.message);
        }
        
        try {
            await pool.query('ALTER TABLE files ADD COLUMN IF NOT EXISTS status VARCHAR(50) NOT NULL DEFAULT \'pending\'');
        } catch (error) {
            console.log('status column already exists or error adding it:', error.message);
        }
        
        // Create indexes for better query performance (ignore errors if they exist)
        try {
            await pool.query('CREATE INDEX IF NOT EXISTS idx_files_user_id ON files(user_id)');
        } catch (error) {
            console.log('user_id index already exists or error creating it:', error.message);
        }
        
        try {
            await pool.query('CREATE INDEX IF NOT EXISTS idx_files_expires_at ON files(expires_at)');
        } catch (error) {
            console.log('expires_at index already exists or error creating it:', error.message);
        }
        
        try {
            await pool.query('CREATE INDEX IF NOT EXISTS idx_files_is_active ON files(is_active)');
        } catch (error) {
            console.log('is_active index already exists or error creating it:', error.message);
        }
        
        try {
            await pool.query('CREATE INDEX IF NOT EXISTS idx_files_upload_date ON files(upload_date)');
        } catch (error) {
            console.log('upload_date index already exists or error creating it:', error.message);
        }
        
        console.log('Database tables and indexes initialized successfully');
    } catch (error) {
        console.error('Error initializing database:', error);
    }
}

// Enhanced health check with Redis and database status
app.get("/health", async (req, res) => {
    try {
        const startTime = Date.now();
        
        // Check database connection
        const dbResult = await pool.query('SELECT COUNT(*) as count FROM files WHERE is_active = true');
        const fileCount = parseInt(dbResult.rows[0].count);
        
        // Check Redis connection
        const redisPing = await redisClient.ping();
        
        // Get memory usage
        const memUsage = process.memoryUsage();
        const memUsageMB = {
            rss: Math.round(memUsage.rss / 1024 / 1024),
            heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
            heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
            external: Math.round(memUsage.external / 1024 / 1024)
        };
        
        const responseTime = Date.now() - startTime;
        
        res.json({ 
            status: "healthy", 
            timestamp: new Date().toISOString(),
            worker: process.pid,
            files: fileCount,
            memory: memUsageMB,
            uptime: process.uptime(),
            responseTime: `${responseTime}ms`,
            redis: redisPing === 'PONG' ? 'connected' : 'disconnected',
            database: 'connected'
        });
    } catch (error) {
        console.error('Health check error:', error);
        res.status(500).json({ 
            status: "unhealthy", 
            error: "Service unavailable",
            worker: process.pid
        });
    }
});

// Authentication endpoints
app.post("/auth/signup", authLimiter, async (req, res) => {
    try {
        const { email, password, name, phone } = req.body;

        // Validate input
        if (!email || !password || !name) {
            return res.status(400).json({ 
                success: false, 
                error: "Email, password, and name are required" 
            });
        }

        if (password.length < 6) {
            return res.status(400).json({ 
                success: false, 
                error: "Password must be at least 6 characters long" 
            });
        }

        // Email validation
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return res.status(400).json({ 
                success: false, 
                error: "Invalid email format" 
            });
        }

        const result = await auth.registerUser(email, password, name, phone);
        res.json(result);
    } catch (error) {
        console.error('Signup error:', error);
        if (error.message === 'User already exists') {
            res.status(409).json({ 
                success: false, 
                error: "User already exists" 
            });
        } else {
            res.status(500).json({ 
                success: false, 
                error: "Registration failed" 
            });
        }
    }
});

app.post("/auth/signin", authLimiter, async (req, res) => {
    try {
        const { email, password } = req.body;

        // Validate input
        if (!email || !password) {
            return res.status(400).json({ 
                success: false, 
                error: "Email and password are required" 
            });
        }

        const result = await auth.loginUser(email, password);
        res.json(result);
    } catch (error) {
        console.error('Signin error:', error);
        if (error.message === 'Invalid email or password') {
            res.status(401).json({ 
                success: false, 
                error: "Invalid email or password" 
            });
        } else {
            res.status(500).json({ 
                success: false, 
                error: "Login failed" 
            });
        }
    }
});

// Protected route example - get user profile
app.get("/auth/profile", auth.authenticateToken, async (req, res) => {
    try {
        const user = await auth.getUserById(req.user.id);
        if (!user) {
            return res.status(404).json({ error: "User not found" });
        }
        
        res.json({
            success: true,
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                phone: user.phone,
                subscriptionTier: user.subscription_tier,
                createdAt: user.created_at,
                lastSignIn: user.last_login
            }
        });
    } catch (error) {
        console.error('Profile error:', error);
        res.status(500).json({ error: "Failed to get profile" });
    }
});

// Update user subscription
app.post("/auth/update-subscription", auth.authenticateToken, async (req, res) => {
    try {
        const { subscriptionTier } = req.body;
        
        if (!subscriptionTier || !['free', 'pro', 'business'].includes(subscriptionTier)) {
            return res.status(400).json({ 
                success: false, 
                error: "Invalid subscription tier. Must be 'free', 'pro', or 'business'" 
            });
        }

        const updatedUser = await auth.updateSubscription(req.user.id, subscriptionTier);
        
        res.json({
            success: true,
            user: {
                id: updatedUser.id,
                email: updatedUser.email,
                name: updatedUser.name,
                subscriptionTier: updatedUser.subscription_tier,
                createdAt: updatedUser.created_at,
                lastSignIn: updatedUser.last_login
            }
        });
    } catch (error) {
        console.error('Subscription update error:', error);
        res.status(500).json({ 
            success: false, 
            error: "Failed to update subscription" 
        });
    }
});

// Sync user data (for when user logs in on new device)
app.get("/auth/sync", auth.authenticateToken, async (req, res) => {
    try {
        const user = await auth.getUserById(req.user.id);
        if (!user) {
            return res.status(404).json({ error: "User not found" });
        }
        
        res.json({
            success: true,
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                phone: user.phone,
                subscriptionTier: user.subscription_tier,
                createdAt: user.created_at,
                lastSignIn: user.last_login
            }
        });
    } catch (error) {
        console.error('Sync error:', error);
        res.status(500).json({ error: "Failed to sync user data" });
    }
});

// Optimized file upload endpoint with caching and concurrency handling
app.post("/upload", uploadLimiter, multer({ 
    dest: uploadsDir,
    limits: {
        fileSize: 5 * 1024 * 1024 * 1024, // 5GB max
        fieldSize: 10 * 1024 * 1024 // 10MB for form fields
    }
}).single("file"), async (req, res) => {
    const startTime = Date.now();
    let fileId, s3Key, userId, uploadDate, expiresAt;

    try {
        if (!req.file) {
            return res.status(400).json({ error: "No file uploaded" });
        }

        fileId = uuidv4();
        uploadDate = new Date();
        expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days
        userId = req.user?.id || null;

        // Insert file metadata into database with status 'pending'
        const client = await pool.connect();
        try {
            await client.query('BEGIN');
            const insertQuery = `
                INSERT INTO files (id, original_name, size, upload_date, expires_at, download_count, is_active, s3_key, s3_bucket, user_id, status)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            `;
            s3Key = `files/${fileId}/${req.file.originalname}`;
            await client.query(insertQuery, [
                fileId,
                req.file.originalname,
                req.file.size,
                uploadDate,
                expiresAt,
                0,
                true,
                s3Key,
                S3_BUCKET_NAME,
                userId,
                'pending'
            ]);
            await client.query('COMMIT');
        } catch (dbError) {
            await client.query('ROLLBACK');
            throw dbError;
        } finally {
            client.release();
        }

        const downloadLink = `https://api.quicksend.vip/download/${fileId}`;
        const uploadTime = Date.now() - startTime;

        // Respond to user immediately
        res.json({
            success: true,
            fileId: fileId,
            downloadLink: downloadLink,
            fileName: req.file.originalname,
            fileSize: req.file.size,
            expiresAt: expiresAt.toISOString(),
            uploadTime: `${uploadTime}ms`,
            worker: process.pid
        });

        // Start async S3 upload in background
        setImmediate(async () => {
            try {
                if (!s3) {
                    console.error(`[Worker ${process.pid}] S3 not initialized, skipping upload for fileId: ${fileId}`);
                    await pool.query('UPDATE files SET status = $1 WHERE id = $2', ['failed', fileId]);
                    return;
                }

                const uploadParams = {
                    Bucket: S3_BUCKET_NAME,
                    Key: s3Key,
                    Body: fs.createReadStream(req.file.path),
                    ContentType: req.file.mimetype || 'application/octet-stream',
                    Metadata: {
                        originalName: req.file.originalname,
                        fileId: fileId,
                        uploadedBy: userId || 'anonymous'
                    }
                };
                await s3.upload(uploadParams).promise();

                // Update DB status to 'uploaded'
                await pool.query('UPDATE files SET status = $1 WHERE id = $2', ['uploaded', fileId]);
                // Delete the temp file
                fs.unlink(req.file.path, () => {});
                console.log(`[Worker ${process.pid}] Async S3 upload complete for fileId: ${fileId}`);
            } catch (err) {
                console.error(`[Worker ${process.pid}] Async S3 upload failed:`, err);
                await pool.query('UPDATE files SET status = $1 WHERE id = $2', ['failed', fileId]);
            }
        });

    } catch (error) {
        console.error(`[Worker ${process.pid}] Upload error:`, error);
        res.status(500).json({ 
            error: "Upload failed",
            worker: process.pid,
            uploadTime: `${Date.now() - startTime}ms`
        });
        // Clean up temp file on error
        if (req.file && req.file.path) {
            fs.unlink(req.file.path, (err) => {
                if (err) console.error(`[Worker ${process.pid}] Error cleaning up temp file:`, err);
            });
        }
    }
});

// Optimized file download endpoint with caching
app.get("/download/:fileId", async (req, res) => {
    const startTime = Date.now();
    const fileId = req.params.fileId;
    
    try {
        console.log(`[Worker ${process.pid}] Download request for fileId: ${fileId}`);
        
        // Check Redis cache first
        const cacheKey = `file_metadata:${fileId}`;
        let fileData = null;
        
        try {
            const cachedData = await redisClient.get(cacheKey);
            if (cachedData) {
                fileData = JSON.parse(cachedData);
                console.log(`[Worker ${process.pid}] File metadata found in cache: ${fileData.original_name}`);
            }
        } catch (cacheError) {
            console.error(`[Worker ${process.pid}] Cache error:`, cacheError);
        }
        
        // If not in cache, get from database
        if (!fileData) {
            const result = await pool.query('SELECT * FROM files WHERE id = $1', [fileId]);
            
            if (result.rows.length === 0) {
                console.log(`[Worker ${process.pid}] File not found in database: ${fileId}`);
                return res.status(404).json({ error: "File not found" });
            }
            
            fileData = result.rows[0];
            
            // Cache the file metadata for 1 hour
            try {
                await redisClient.setex(cacheKey, 3600, JSON.stringify(fileData));
            } catch (cacheError) {
                console.error(`[Worker ${process.pid}] Failed to cache file metadata:`, cacheError);
            }
        }
        
        console.log(`[Worker ${process.pid}] File found: ${fileData.original_name}`);
        
        if (!fileData.is_active) {
            console.log(`[Worker ${process.pid}] File is inactive: ${fileId}`);
            return res.status(404).json({ error: "File not found" });
        }

        if (new Date() > new Date(fileData.expires_at)) {
            console.log(`[Worker ${process.pid}] File has expired: ${fileId}`);
            // Mark file as inactive
            await pool.query('UPDATE files SET is_active = false WHERE id = $1', [fileId]);
            // Remove from cache
            await redisClient.del(cacheKey);
            return res.status(410).json({ error: "File has expired" });
        }

        // Increment download count asynchronously (don't block the response)
        pool.query('UPDATE files SET download_count = download_count + 1 WHERE id = $1', [fileId])
            .catch(err => console.error(`[Worker ${process.pid}] Error updating download count:`, err));
        
        // Generate S3 presigned URL for download with retry logic
        if (fileData.s3_key && fileData.s3_bucket) {
            const generatePresignedUrl = async (retries = 3) => {
                for (let attempt = 1; attempt <= retries; attempt++) {
                    try {
                        const params = {
                            Bucket: fileData.s3_bucket,
                            Key: fileData.s3_key,
                            Expires: 3600, // URL expires in 1 hour
                            ResponseContentDisposition: `attachment; filename="${fileData.original_name}"`
                        };
                        
                        const presignedUrl = await s3.getSignedUrlPromise('getObject', params);
                        console.log(`[Worker ${process.pid}] Generated presigned URL on attempt ${attempt}: ${fileId}`);
                        return presignedUrl;
                    } catch (s3Error) {
                        console.error(`[Worker ${process.pid}] S3 presigned URL attempt ${attempt} failed:`, s3Error);
                        if (attempt === retries) throw s3Error;
                        await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
                    }
                }
            };

            try {
                const presignedUrl = await generatePresignedUrl();
                const responseTime = Date.now() - startTime;
                console.log(`[Worker ${process.pid}] Download redirect in ${responseTime}ms: ${fileId}`);
                res.redirect(presignedUrl);
            } catch (s3Error) {
                console.error(`[Worker ${process.pid}] All S3 presigned URL attempts failed:`, s3Error);
                res.status(500).json({ error: "Failed to generate download link" });
            }
        } else {
            console.log(`[Worker ${process.pid}] No S3 key found for file: ${fileId}`);
            res.status(404).json({ error: "File not found" });
        }
    } catch (error) {
        console.error(`[Worker ${process.pid}] Download error:`, error);
        res.status(500).json({ 
            error: "Download failed",
            worker: process.pid,
            responseTime: `${Date.now() - startTime}ms`
        });
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

// S3 Presigned Upload URL
app.post('/s3/upload-url', auth.authenticateToken, async (req, res) => {
  const { fileName, fileType } = req.body;
  if (!fileName || !fileType) {
    return res.status(400).json({ error: 'fileName and fileType are required' });
  }
  const fileId = uuidv4();
  const s3Key = `files/${fileId}/${fileName}`;
  const params = {
    Bucket: S3_BUCKET_NAME,
    Key: s3Key,
    Expires: 600, // 10 minutes
    ContentType: fileType,
    Metadata: {
      uploadedBy: req.user.id || 'anonymous'
    }
  };
  try {
    const url = await s3.getSignedUrlPromise('putObject', params);
    res.json({ url, fileId, s3Key });
  } catch (err) {
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

// S3 Presigned Download URL
app.post('/s3/download-url', auth.authenticateToken, async (req, res) => {
  const { s3Key } = req.body;
  if (!s3Key) {
    return res.status(400).json({ error: 's3Key is required' });
  }
  const params = {
    Bucket: S3_BUCKET_NAME,
    Key: s3Key,
    Expires: 600 // 10 minutes
  };
  try {
    const url = await s3.getSignedUrlPromise('getObject', params);
    res.json({ url });
  } catch (err) {
    res.status(500).json({ error: 'Failed to generate download URL' });
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
