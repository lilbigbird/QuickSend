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
require("dotenv").config();

// Single process server (clustering disabled for now)
console.log(`🚀 QuickSend server starting...`);
console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
console.log(`Process ID: ${process.pid}`);

// Enhanced keep-alive mechanism to prevent Render free instance from sleeping
const keepAliveInterval = setInterval(async () => {
    const now = new Date().toISOString();
    console.log(`💓 Keep-alive ping: ${now}`);
    
    // Ping our own health endpoint to keep the instance warm
    const pingServer = async (retryCount = 0) => {
        try {
            const https = require('https');
            const url = process.env.RENDER_EXTERNAL_URL || `https://api.quicksend.vip`;
            
            // Try health endpoint first, then root endpoint as fallback
            const endpoints = ['/health', '/'];
            
            for (const endpoint of endpoints) {
                try {
                    return await new Promise((resolve, reject) => {
                        const req = https.get(`${url}${endpoint}`, (res) => {
                            console.log(`💓 Keep-alive response: ${res.statusCode} from ${endpoint} (attempt ${retryCount + 1})`);
                            if (res.statusCode === 200) {
                                resolve(true);
                            } else {
                                reject(new Error(`HTTP ${res.statusCode}`));
                            }
                        });
                        
                        req.on('error', (err) => {
                            console.log(`💓 Keep-alive error: ${err.message} from ${endpoint} (attempt ${retryCount + 1})`);
                            reject(err);
                        });
                        
                        req.setTimeout(10000, () => {
                            req.destroy();
                            reject(new Error('Timeout'));
                        });
                    });
                } catch (endpointError) {
                    console.log(`💓 Endpoint ${endpoint} failed, trying next...`);
                    if (endpoint === '/') {
                        throw endpointError; // If both endpoints fail, throw the error
                    }
                }
            }
        } catch (error) {
            console.log(`💓 Keep-alive failed: ${error.message} (attempt ${retryCount + 1})`);
            throw error;
        }
    };
    
    // Try up to 3 times with exponential backoff
    for (let attempt = 0; attempt < 3; attempt++) {
        try {
            await pingServer(attempt);
            console.log(`💓 Keep-alive successful on attempt ${attempt + 1}`);
            break;
        } catch (error) {
            if (attempt === 2) {
                console.error(`💓 Keep-alive failed after 3 attempts: ${error.message}`);
            } else {
                console.log(`💓 Retrying keep-alive in ${(attempt + 1) * 2} seconds...`);
                await new Promise(resolve => setTimeout(resolve, (attempt + 1) * 2000));
            }
        }
    }
}, 8 * 60 * 1000); // Every 8 minutes (more frequent to prevent spin-down)

// Cleanup expired files every hour
const cleanupInterval = setInterval(async () => {
    try {
        console.log(`🧹 Starting cleanup of expired files...`);
        
        // Get expired files from database
        const result = await pool.query(
            'SELECT id, s3_key, s3_bucket FROM files WHERE expires_at < NOW() AND is_active = true'
        );
        
        if (result.rows.length > 0) {
            console.log(`🧹 Found ${result.rows.length} expired files to clean up`);
            
            for (const file of result.rows) {
                try {
                    // Delete from S3
                    if (file.s3_key && file.s3_bucket) {
                        await s3.deleteObject({
                            Bucket: file.s3_bucket,
                            Key: file.s3_key
                        }).promise();
                        console.log(`🧹 Deleted from S3: ${file.id}`);
                    }
                    
                    // Mark as inactive in database
                    await pool.query(
                        'UPDATE files SET is_active = false WHERE id = $1',
                        [file.id]
                    );
                    console.log(`🧹 Marked as inactive: ${file.id}`);
                } catch (error) {
                    console.error(`🧹 Error cleaning up file ${file.id}:`, error);
                }
            }
            
            console.log(`🧹 Cleanup completed for ${result.rows.length} files`);
        } else {
            console.log(`🧹 No expired files found`);
        }
    } catch (error) {
        console.error(`🧹 Cleanup error:`, error);
    }
}, 60 * 60 * 1000); // Every hour

// Cleanup on process exit
process.on('SIGINT', () => {
    console.log('🛑 Shutting down server...');
    clearInterval(keepAliveInterval);
    clearInterval(cleanupInterval);
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('🛑 Shutting down server...');
    clearInterval(keepAliveInterval);
    clearInterval(cleanupInterval);
    process.exit(0);
});

// Configure AWS S3 with tiered settings for business plan (5GB support)
let s3;
try {
    s3 = new AWS.S3({
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
        region: process.env.AWS_REGION || 'us-east-2',
        signatureVersion: 'v4',
        httpOptions: {
            timeout: 3600000, // 60 minutes for large files (increased)
            connectTimeout: 30000, // 30 seconds
            maxRetries: 3, // Moderate retry count
            agent: false,
            // Optimized for large files
            keepAlive: false,
            keepAliveMsecs: 1000,
            maxSockets: 16, // Increased for better performance
            maxFreeSockets: 8
        },
        maxRetries: 3,
        retryDelayOptions: {
            base: 300, // Moderate retry base
            customBackoff: (retryCount) => Math.min(1000 * Math.pow(2, retryCount), 8000)
        }
    });
    console.log(`✅ S3 initialized with optimized settings for region: ${process.env.AWS_REGION || 'us-east-2'}`);
} catch (error) {
    console.error('Error initializing S3:', error);
    s3 = null;
}

// Optimized S3 upload configuration for Pro/Business tiers
const s3UploadConfig = {
    partSize: 100 * 1024 * 1024, // 100MB parts (good balance)
    queueSize: 10, // Increased concurrent parts for Pro/Business
    leavePartsOnError: false,
    // Additional optimizations for large files
    multipartThreshold: 100 * 1024 * 1024, // Start multipart at 100MB
    multipartConcurrency: 10 // Increased concurrent parts for Pro/Business
};

const S3_BUCKET_NAME = process.env.S3_BUCKET_NAME || 'quicksend-files-sour';

// Redis client for caching and session management (optional)
let redisClient = null;

if (process.env.REDIS_URL) {
    try {
        redisClient = Redis.createClient({
            url: process.env.REDIS_URL,
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
            console.log('✅ Redis Client Connected');
        });
    } catch (error) {
        console.log('⚠️ Redis not configured, running without caching');
    }
} else {
    console.log('⚠️ Redis not configured, running without caching');
}

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
                user_id UUID,
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
        
        try {
            await pool.query('ALTER TABLE files ADD COLUMN IF NOT EXISTS upload_id VARCHAR(255)');
        } catch (error) {
            console.log('upload_id column already exists or error adding it:', error.message);
        }
        
        try {
            await pool.query('ALTER TABLE files ADD COLUMN IF NOT EXISTS original_size BIGINT');
        } catch (error) {
            console.log('original_size column already exists or error adding it:', error.message);
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

// Simple health check for Render
app.get("/", (req, res) => {
    res.json({ 
        status: "QuickSend API is running", 
        timestamp: new Date().toISOString(),
        worker: process.pid,
        port: PORT,
        environment: process.env.NODE_ENV || "development"
    });
});

// Test endpoint for Render port detection
app.get("/test", (req, res) => {
    res.json({ 
        message: "Server is responding", 
        timestamp: new Date().toISOString(),
        pid: process.pid
    });
});



// Simple root endpoint for keep-alive pings
app.get("/", (req, res) => {
    res.json({ 
        status: "QuickSend API is running", 
        timestamp: new Date().toISOString(),
        worker: process.pid,
        uptime: process.uptime()
    });
});

// Keep-alive status endpoint for monitoring
app.get("/keepalive-status", (req, res) => {
    const now = new Date();
    const lastPing = new Date(now.getTime() - (8 * 60 * 1000)); // 8 minutes ago
    
    res.json({
        status: "Keep-alive monitoring",
        timestamp: now.toISOString(),
        worker: process.pid,
        uptime: process.uptime(),
        lastPingTime: lastPing.toISOString(),
        nextPingIn: "~8 minutes",
        pingInterval: "8 minutes",
        endpoints: ["/health", "/"],
        renderUrl: process.env.RENDER_EXTERNAL_URL || "https://api.quicksend.vip"
    });
});

// Enhanced health check with Redis and database status
app.get("/health", async (req, res) => {
    try {
        const startTime = Date.now();
        
        // Check database connection
        const dbResult = await pool.query('SELECT COUNT(*) as count FROM files WHERE is_active = true');
        const fileCount = parseInt(dbResult.rows[0].count);
        
        // Check Redis connection (optional)
        let redisStatus = 'not configured';
        if (redisClient) {
            try {
                const redisPing = await redisClient.ping();
                redisStatus = redisPing === 'PONG' ? 'connected' : 'disconnected';
            } catch (redisError) {
                redisStatus = 'error';
            }
        }
        
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
            redis: redisStatus,
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

// Update user subscription (simplified without authentication)
app.post('/auth/update-subscription', async (req, res) => {
  const { subscriptionTier } = req.body;
  if (!subscriptionTier) {
    return res.status(400).json({ success: false, error: 'Missing subscriptionTier' });
  }
  try {
    // For now, we'll create a simple response since we're removing user authentication
    // In the future, this can be integrated with StoreKit for subscription management
    res.json({
      success: true,
      user: {
        id: 'guest_user',
        email: 'guest@quicksend.app',
        name: 'Guest User',
        subscriptionTier: subscriptionTier,
        createdAt: new Date().toISOString(),
        lastLogin: new Date().toISOString(),
        nextBillingDate: subscriptionTier !== 'free' ? new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString() : null
      }
    });
  } catch (err) {
    console.error('Update subscription error:', err);
    res.status(500).json({ success: false, error: 'Server error' });
  }
});

// Optimized file upload endpoint with caching and concurrency handling
app.post("/upload", uploadLimiter, (req, res, next) => {
    console.log(`[Worker ${process.pid}] Upload request received`);
    console.log(`[Worker ${process.pid}] Content-Type:`, req.headers['content-type']);
    console.log(`[Worker ${process.pid}] Content-Length:`, req.headers['content-length']);
    console.log(`[Worker ${process.pid}] User-Agent:`, req.headers['user-agent']);
    
    const upload = multer({ 
    dest: uploadsDir,
    limits: {
        fileSize: 5 * 1024 * 1024 * 1024, // 5GB max
        fieldSize: 10 * 1024 * 1024 // 10MB for form fields
    }
    }).single("file");
    
    upload(req, res, (err) => {
        if (err instanceof multer.MulterError) {
            console.error(`[Worker ${process.pid}] Multer error:`, err);
            if (err.code === 'LIMIT_FILE_SIZE') {
                return res.status(400).json({ 
                    error: "File too large",
                    details: "Maximum file size is 5GB"
                });
            }
            return res.status(400).json({ 
                error: "File upload error",
                details: err.message
            });
        } else if (err) {
            console.error(`[Worker ${process.pid}] Upload error:`, err);
            return res.status(500).json({ 
                error: "Upload failed",
                details: err.message
            });
        }
        next();
    });
}, async (req, res) => {
    const startTime = Date.now();
    let fileId, s3Key, userId, uploadDate, expiresAt;

    try {
        console.log(`[Worker ${process.pid}] Upload request received`);
        console.log(`[Worker ${process.pid}] Request body:`, req.body);
        console.log(`[Worker ${process.pid}] Request file:`, req.file);
        console.log(`[Worker ${process.pid}] Request headers:`, req.headers['content-type']);

        if (!req.file) {
            console.error(`[Worker ${process.pid}] No file in request`);
            return res.status(400).json({ 
                error: "No file uploaded",
                details: "Please ensure you're sending a file with the field name 'file'",
                contentType: req.headers['content-type']
            });
        }

        fileId = uuidv4();
        uploadDate = new Date();
        expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days
        userId = null; // No authentication, so no user ID

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
        
        // Check Redis cache first (only if Redis is available)
        const cacheKey = `file_metadata:${fileId}`;
        let fileData = null;
        
        if (redisClient) {
            try {
                const cachedData = await redisClient.get(cacheKey);
                if (cachedData) {
                    fileData = JSON.parse(cachedData);
                    console.log(`[Worker ${process.pid}] File metadata found in cache: ${fileData.original_name}`);
                }
            } catch (cacheError) {
                console.error(`[Worker ${process.pid}] Cache error:`, cacheError);
            }
        }
        
        // If not in cache, get from database
        if (!fileData) {
        const result = await pool.query('SELECT * FROM files WHERE id = $1', [fileId]);
        
        if (result.rows.length === 0) {
                console.log(`[Worker ${process.pid}] File not found in database: ${fileId}`);
            return res.status(404).json({ error: "File not found" });
            }
            
            fileData = result.rows[0];
            

            
            // Cache the file metadata for 1 hour (only if Redis is available)
            if (redisClient) {
                try {
                    await redisClient.setex(cacheKey, 3600, JSON.stringify(fileData));
                } catch (cacheError) {
                    console.error(`[Worker ${process.pid}] Failed to cache file metadata:`, cacheError);
                }
            }
        }
        
        console.log(`[Worker ${process.pid}] File found: ${fileData.original_name}`);
        
        // Check if file is active
        if (!fileData.is_active) {
            console.log(`[Worker ${process.pid}] File is inactive: ${fileId}`);
            return res.status(404).json({ error: "File not found" });
        }
        
        // Block only if status is 'pending' or 'failed'
        if (fileData.status === 'pending') {
            console.log(`[Worker ${process.pid}] File upload still in progress: ${fileId}`);
            return res.status(423).json({ error: "File upload in progress, please try again in a moment" });
        }
        if (fileData.status === 'failed') {
            console.log(`[Worker ${process.pid}] File upload failed: ${fileId}`);
            return res.status(500).json({ error: "File upload failed" });
        }
        // Otherwise, proceed (including status === null and status === 'uploaded')

        if (new Date() > new Date(fileData.expires_at)) {
            console.log(`[Worker ${process.pid}] File has expired: ${fileId}`);
            // Mark file as inactive
            await pool.query('UPDATE files SET is_active = false WHERE id = $1', [fileId]);
            // Remove from cache (only if Redis is available)
            if (redisClient) {
                try {
                    await redisClient.del(cacheKey);
                } catch (cacheError) {
                    console.error(`[Worker ${process.pid}] Error removing from cache:`, cacheError);
                }
            }
            return res.status(410).json({ error: "File has expired" });
        }

        // Increment download count asynchronously (don't block the response)
        pool.query('UPDATE files SET download_count = download_count + 1 WHERE id = $1', [fileId])
            .catch(err => console.error(`[Worker ${process.pid}] Error updating download count:`, err));
        
        // Generate S3 presigned URL for download
        if (fileData.s3_key && fileData.s3_bucket) {
            try {
                // Verify the file exists in S3
                try {
                    await s3.headObject({
                        Bucket: fileData.s3_bucket,
                        Key: fileData.s3_key
                    }).promise();
                    console.log(`[Worker ${process.pid}] File verified in S3: ${fileId}`);
                } catch (headError) {
                    console.error(`[Worker ${process.pid}] File not found in S3: ${fileId}`, headError);
                    return res.status(404).json({ error: "File not found in S3" });
                }
                
                // Generate presigned URL for download
                const encodedFilename = encodeURIComponent(fileData.original_name).replace(/['()]/g, escape);
                const isLargeFile = fileData.size > 100 * 1024 * 1024; // 100MB threshold
                const expirationTime = isLargeFile ? 7200 : 3600; // 2 hours for large files, 1 hour for others
                
                const params = {
                    Bucket: fileData.s3_bucket,
                    Key: fileData.s3_key,
                    Expires: expirationTime,
                    ResponseContentDisposition: `attachment; filename="${encodedFilename}"; filename*=UTF-8''${encodeURIComponent(fileData.original_name)}`
                };
                
                const presignedUrl = await s3.getSignedUrlPromise('getObject', params);
                const responseTime = Date.now() - startTime;
                console.log(`[Worker ${process.pid}] Download redirect in ${responseTime}ms: ${fileId}`);
                res.redirect(presignedUrl);
            } catch (error) {
                console.error(`[Worker ${process.pid}] Download error:`, error);
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

// Check upload limits endpoint
app.post('/check-upload-limits', async (req, res) => {
  const { fileSize, subscriptionTier } = req.body;
  
  // Default to free tier if not specified
  const tier = subscriptionTier || 'free';
  
  // Define tier limits
  const tierLimits = {
    free: {
      maxFileSize: 100 * 1024 * 1024, // 100MB
      maxUploadsPerMonth: 10,
      expiryDays: 7
    },
    pro: {
      maxFileSize: 1024 * 1024 * 1024, // 1GB
      maxUploadsPerMonth: 100,
      expiryDays: 30
    },
    business: {
      maxFileSize: 5 * 1024 * 1024 * 1024, // 5GB
      maxUploadsPerMonth: 1000,
      expiryDays: 90
    }
  };
  
  const limits = tierLimits[tier] || tierLimits.free;
  
  // Check file size limit
  if (fileSize && fileSize > limits.maxFileSize) {
    return res.status(413).json({
      error: 'File too large',
      message: `Your ${tier} plan has a ${formatBytes(limits.maxFileSize)} file size limit. The selected file is ${formatBytes(fileSize)}.`,
      currentTier: tier,
      maxFileSize: limits.maxFileSize,
      fileSize: fileSize
    });
  }
  
  // Check monthly upload limit (for now, we'll return success and let the client handle it)
  // In a real implementation, you'd check against a database
  res.json({
    success: true,
    limits: limits,
    currentTier: tier
  });
});

// Helper function to format bytes
function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// S3 Presigned Upload URL (works for both authenticated and unauthenticated users)
app.post('/s3/upload-url', async (req, res) => {
  const { fileName, fileType, fileSize, subscriptionTier } = req.body;
  if (!fileName || !fileType) {
    return res.status(400).json({ error: 'fileName and fileType are required' });
  }
  
  // Get user ID if authenticated, otherwise use 'anonymous'
  const userId = null; // No authentication, so no user ID
  
  const fileId = uuidv4();
  const s3Key = `files/${fileId}/${fileName}`;
  const uploadDate = new Date();
  
  // Tier-based expiration times
  const tierLimits = {
    free: { expiryDays: 7 },
    pro: { expiryDays: 30 },
    business: { expiryDays: 90 }
  };
  
  const tier = subscriptionTier || 'free';
  const expiryDays = tierLimits[tier]?.expiryDays || 7;
  const expiresAt = new Date(Date.now() + expiryDays * 24 * 60 * 60 * 1000);
  
  // Tiered expiration times with Pro/Business optimizations
  const isLargeFile = fileSize && fileSize > 100 * 1024 * 1024; // 100MB threshold
  const isVeryLargeFile = fileSize && fileSize > 1 * 1024 * 1024 * 1024; // 1GB threshold
  
  let expirationTime = 3600; // 1 hour default for Free tier
  
  if (tier === 'pro' || tier === 'business') {
    // Pro/Business tiers get longer expiration times for better upload reliability
    if (isVeryLargeFile) {
      expirationTime = 28800; // 8 hours for very large files (1GB+) on Pro/Business
    } else if (isLargeFile) {
      expirationTime = 14400; // 4 hours for large files (100MB-1GB) on Pro/Business
    } else {
      expirationTime = 7200; // 2 hours for smaller files on Pro/Business
    }
  } else {
    // Free tier keeps original times
    if (isVeryLargeFile) {
      expirationTime = 14400; // 4 hours for very large files (1GB+)
    } else if (isLargeFile) {
      expirationTime = 7200; // 2 hours for large files (100MB-1GB)
    }
  }
  
  const params = {
    Bucket: S3_BUCKET_NAME,
    Key: s3Key,
    Expires: expirationTime,
    ContentType: fileType,
    Metadata: {
      uploadedBy: userId ? userId : 'anonymous',
      fileSize: fileSize ? fileSize.toString() : '0',
      isLargeFile: isLargeFile ? 'true' : 'false',
      isVeryLargeFile: isVeryLargeFile ? 'true' : 'false'
    }
  };
  

  
  try {
    // Create database record first
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const insertQuery = `
        INSERT INTO files (id, original_name, size, upload_date, expires_at, download_count, is_active, s3_key, s3_bucket, user_id, status)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      `;
      await client.query(insertQuery, [
        fileId,
        fileName,
        fileSize || 0,
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
      console.error('Database error:', dbError);
      throw dbError;
    } finally {
      client.release();
    }
    
    const url = await s3.getSignedUrlPromise('putObject', params);
    
    res.json({ url, fileId, s3Key });
  } catch (err) {
    console.error('S3 upload URL generation error:', err);
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

// S3 Upload Complete - Update file status after successful S3 upload
app.post('/s3/upload-complete', async (req, res) => {
  const { fileId, fileSize } = req.body;
  if (!fileId) {
    return res.status(400).json({ error: 'fileId is required' });
  }
  
  try {
    // Verify the file exists in S3
    const result = await pool.query('SELECT s3_key, s3_bucket FROM files WHERE id = $1', [fileId]);
    
    if (result.rows.length === 0) {
      console.log(`[Worker ${process.pid}] File not found in database: ${fileId}`);
      return res.status(404).json({ error: 'File not found' });
    }
    
    const fileData = result.rows[0];
    
    try {
      await s3.headObject({
        Bucket: fileData.s3_bucket,
        Key: fileData.s3_key
      }).promise();
      console.log(`[Worker ${process.pid}] File verified in S3: ${fileId}`);
    } catch (headError) {
      console.error(`[Worker ${process.pid}] File not found in S3: ${fileId}`, headError);
      return res.status(404).json({ error: 'File not found in S3' });
    }
    
    // Update file status to 'uploaded' and update file size if provided
    const updateQuery = fileSize ? 
      'UPDATE files SET status = $1, size = $2 WHERE id = $3' :
      'UPDATE files SET status = $1 WHERE id = $3';
    
    const updateParams = fileSize ? 
      ['uploaded', fileSize, fileId] :
      ['uploaded', fileId];
    
    await pool.query(updateQuery, updateParams);
    console.log(`[Worker ${process.pid}] Updated file status to uploaded: ${fileId}`);
    
    res.json({ success: true, message: 'Upload completed successfully' });
  } catch (err) {
    console.error(`[Worker ${process.pid}] Upload complete error:`, err);
    res.status(500).json({ error: 'Failed to complete upload' });
  }
});

// S3 Multipart Upload Initiation for Pro/Business tiers
app.post('/s3/multipart-upload', async (req, res) => {
  const { fileName, fileType, fileSize, subscriptionTier } = req.body;
  if (!fileName || !fileType || !fileSize) {
    return res.status(400).json({ error: 'fileName, fileType, and fileSize are required' });
  }
  
  // Only allow multipart uploads for Pro/Business tiers
  const tier = subscriptionTier || 'free';
  if (tier === 'free') {
    return res.status(403).json({ error: 'Multipart uploads only available for Pro/Business tiers' });
  }
  
  const fileId = uuidv4();
  const s3Key = `files/${fileId}/${fileName}`;
  const uploadDate = new Date();
  
  // Tier-based expiration times
  const tierLimits = {
    free: { expiryDays: 7 },
    pro: { expiryDays: 30 },
    business: { expiryDays: 90 }
  };
  
  const expiryDays = tierLimits[tier]?.expiryDays || 7;
  const expiresAt = new Date(Date.now() + expiryDays * 24 * 60 * 60 * 1000);
  
  try {
    // Create multipart upload in S3
    const multipartParams = {
      Bucket: S3_BUCKET_NAME,
      Key: s3Key,
      ContentType: fileType,
      Metadata: {
        uploadedBy: 'anonymous',
        fileSize: fileSize.toString(),
        subscriptionTier: tier
      }
    };
    
    const multipartResult = await s3.createMultipartUpload(multipartParams).promise();
    
    // Create database record
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const insertQuery = `
        INSERT INTO files (id, original_name, size, upload_date, expires_at, download_count, is_active, s3_key, s3_bucket, user_id, status, upload_id)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      `;
      await client.query(insertQuery, [
        fileId,
        fileName,
        fileSize,
        uploadDate,
        expiresAt,
        0,
        true,
        s3Key,
        S3_BUCKET_NAME,
        null,
        'pending',
        multipartResult.UploadId
      ]);
      await client.query('COMMIT');
    } catch (dbError) {
      await client.query('ROLLBACK');
      console.error('Database error:', dbError);
      throw dbError;
    } finally {
      client.release();
    }
    
    // Generate presigned URLs for parts (200MB parts for fewer total parts)
    const partSize = 200 * 1024 * 1024;
    const totalParts = Math.ceil(fileSize / partSize);
    const partUrls = [];
    
    for (let partNumber = 1; partNumber <= totalParts; partNumber++) {
      const partParams = {
        Bucket: S3_BUCKET_NAME,
        Key: s3Key,
        UploadId: multipartResult.UploadId,
        PartNumber: partNumber,
        Expires: 3600 // 1 hour for each part
      };
      
      const partUrl = await s3.getSignedUrlPromise('uploadPart', partParams);
      partUrls.push(partUrl);
    }
    
    res.json({
      uploadId: multipartResult.UploadId,
      fileId: fileId,
      partUrls: partUrls,
      bucket: S3_BUCKET_NAME,
      key: s3Key
    });
  } catch (err) {
    console.error('Multipart upload initiation error:', err);
    res.status(500).json({ error: 'Failed to initiate multipart upload' });
  }
});

// Complete multipart upload
app.post('/s3/complete-multipart', async (req, res) => {
  const { uploadId, fileId, parts } = req.body;
  if (!uploadId || !fileId || !parts) {
    return res.status(400).json({ error: 'uploadId, fileId, and parts are required' });
  }
  
  try {
    // Get file info from database
    const result = await pool.query('SELECT s3_key, s3_bucket FROM files WHERE id = $1', [fileId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'File not found' });
    }
    
    const fileData = result.rows[0];
    
    // Complete multipart upload in S3
    const completeParams = {
      Bucket: fileData.s3_bucket,
      Key: fileData.s3_key,
      UploadId: uploadId,
      MultipartUpload: {
        Parts: parts.map(part => ({
          PartNumber: part.PartNumber,
          ETag: part.ETag
        }))
      }
    };
    
    const completeResult = await s3.completeMultipartUpload(completeParams).promise();
    
    // Update file status
    await pool.query('UPDATE files SET status = $1 WHERE id = $2', ['uploaded', fileId]);
    
    // Return standard upload response
    res.json({
      success: true,
      fileId: fileId,
      downloadLink: `https://api.quicksend.vip/download/${fileId}`,
      fileName: fileData.s3_key.split('/').pop(),
      fileSize: parts.length * 100 * 1024 * 1024, // Approximate
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
    });
  } catch (err) {
    console.error('Complete multipart upload error:', err);
    res.status(500).json({ error: 'Failed to complete multipart upload' });
  }
});

// Cancel multipart upload
app.post('/s3/cancel-multipart', async (req, res) => {
  const { uploadId, fileId } = req.body;
  if (!uploadId || !fileId) {
    return res.status(400).json({ error: 'uploadId and fileId are required' });
  }
  
  try {
    // Get file info from database
    const result = await pool.query('SELECT s3_key, s3_bucket FROM files WHERE id = $1', [fileId]);
    if (result.rows.length > 0) {
      const fileData = result.rows[0];
      
      // Abort multipart upload in S3
      const abortParams = {
        Bucket: fileData.s3_bucket,
        Key: fileData.s3_key,
        UploadId: uploadId
      };
      
      await s3.abortMultipartUpload(abortParams).promise();
      
      // Mark file as failed
      await pool.query('UPDATE files SET status = $1 WHERE id = $2', ['failed', fileId]);
    }
    
    res.json({ success: true, message: 'Multipart upload cancelled' });
  } catch (err) {
    console.error('Cancel multipart upload error:', err);
    res.status(500).json({ error: 'Failed to cancel multipart upload' });
  }
});

// Store encryption metadata (IV) for file decryption
app.post('/store-encryption-metadata', async (req, res) => {
  const { fileId, iv, originalSize } = req.body;
  if (!fileId || !iv || !originalSize) {
    return res.status(400).json({ error: 'fileId, iv, and originalSize are required' });
  }
  
  try {
    // Store IV and original size in database
    await pool.query(
      'UPDATE files SET encryption_iv = $1, original_size = $2 WHERE id = $3',
      [iv, originalSize, fileId]
    );
    
    res.json({ success: true, message: 'Encryption metadata stored' });
  } catch (err) {
    console.error('Store encryption metadata error:', err);
    res.status(500).json({ error: 'Failed to store encryption metadata' });
  }
});

// S3 Presigned Download URL (works for both authenticated and unauthenticated users)
app.post('/s3/download-url', async (req, res) => {
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
    console.error('S3 download URL generation error:', err);
    res.status(500).json({ error: 'Failed to generate download URL' });
  }
});



// Start server immediately
const server = app.listen(PORT, '0.0.0.0', async () => {
    console.log(`🚀 QuickSend API server running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
    console.log(`Upload endpoint: /upload`);
    console.log(`Download endpoint: /download/:fileId`);
    console.log(`Health check: /health`);
    console.log(`Root endpoint: /`);
    
    // Initialize database
    try {
        await initializeDatabase();
        console.log(`✅ Database connected and initialized`);
    } catch (err) {
        console.error('❌ Database initialization failed:', err);
    }
    
    // Immediate keep-alive ping to ensure instance is active
    setTimeout(async () => {
        console.log(`💓 Initial keep-alive ping...`);
        try {
            const https = require('https');
            const url = process.env.RENDER_EXTERNAL_URL || `https://api.quicksend.vip`;
            
            // Try both endpoints for initial ping
            const endpoints = ['/health', '/'];
            let success = false;
            
            for (const endpoint of endpoints) {
                try {
                    await new Promise((resolve, reject) => {
                        const req = https.get(`${url}${endpoint}`, (res) => {
                            console.log(`💓 Initial keep-alive response: ${res.statusCode} from ${endpoint}`);
                            if (res.statusCode === 200) {
                                success = true;
                                resolve();
                            } else {
                                reject(new Error(`HTTP ${res.statusCode}`));
                            }
                        });
                        
                        req.on('error', (err) => {
                            console.log(`💓 Initial keep-alive error: ${err.message} from ${endpoint}`);
                            reject(err);
                        });
                        
                        req.setTimeout(10000, () => {
                            req.destroy();
                            reject(new Error('Timeout'));
                        });
                    });
                    
                    if (success) break;
                } catch (endpointError) {
                    console.log(`💓 Initial endpoint ${endpoint} failed, trying next...`);
                    if (endpoint === '/') {
                        console.log(`💓 Initial keep-alive failed for all endpoints: ${endpointError.message}`);
                    }
                }
            }
        } catch (error) {
            console.log(`💓 Initial keep-alive failed: ${error.message}`);
        }
    }, 5000); // Wait 5 seconds after server starts
});

// Handle server errors
server.on('error', (error) => {
    if (error.syscall !== 'listen') {
        throw error;
    }

    const bind = typeof PORT === 'string' ? 'Pipe ' + PORT : 'Port ' + PORT;

    switch (error.code) {
        case 'EACCES':
            console.error(bind + ' requires elevated privileges');
            process.exit(1);
            break;
        case 'EADDRINUSE':
            console.error(bind + ' is already in use');
            process.exit(1);
            break;
        default:
            throw error;
    }
});

module.exports = app;
