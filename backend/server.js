const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');
const userDB = require('./userDatabase');
require('dotenv').config();
<<<<<<< HEAD
const AWS = require('aws-sdk');
const bcrypt = require('bcrypt');

// AWS S3 Configuration
const s3 = new AWS.S3({
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'YOUR_ACCESS_KEY_ID',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'YOUR_SECRET_ACCESS_KEY',
    region: process.env.AWS_REGION || 'us-east-1'
});

const BUCKET_NAME = process.env.S3_BUCKET_NAME || 'quicksend-files-sour';
=======
>>>>>>> 9b57587dd035c392806c41dbdf72d7e547627a5b

const app = express();
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'production';

// Subscription tiers configuration
const SUBSCRIPTION_TIERS = {
    free: {
        maxFileSize: 100 * 1024 * 1024, // 100MB
        maxExpiryDays: 7,
        maxUploadsPerMonth: 10,
        features: ['Basic file sharing', '7-day expiry', 'Standard support']
    },
    pro: {
        maxFileSize: 1024 * 1024 * 1024, // 1GB
        maxExpiryDays: 30,
        maxUploadsPerMonth: 100,
        features: ['Large file support', '30-day expiry', 'Priority support', 'No ads', 'Advanced analytics']
    },
    business: {
        maxFileSize: 5 * 1024 * 1024 * 1024, // 5GB
        maxExpiryDays: 90,
        maxUploadsPerMonth: 1000,
        features: ['Enterprise file sharing', '90-day expiry', 'Custom branding', 'API access', 'Team management']
    }
};

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// File-based database for file metadata
const databaseFile = path.join(__dirname, 'fileDatabase.json');

// Load database from file
function loadDatabase() {
    try {
        if (fs.existsSync(databaseFile)) {
            const data = fs.readFileSync(databaseFile, 'utf8');
            const parsed = JSON.parse(data);
            // Convert back to Map
            const map = new Map();
            for (const [key, value] of Object.entries(parsed)) {
                map.set(key, value);
            }
            return map;
        }
    } catch (error) {
        console.error('Error loading database:', error);
    }
    return new Map();
}

// Save database to file
function saveDatabase(database) {
    try {
        // Convert Map to object for JSON serialization
        const obj = {};
        for (const [key, value] of database) {
            obj[key] = value;
        }
        fs.writeFileSync(databaseFile, JSON.stringify(obj, null, 2));
    } catch (error) {
        console.error('Error saving database:', error);
    }
}

// Initialize database
let fileDatabase = loadDatabase();

// Clean up expired files on startup
function cleanupExpiredFiles() {
    const now = new Date();
    const expiredFiles = [];
    
    for (const [fileId, fileData] of fileDatabase) {
        if (new Date(fileData.expiresAt) < now) {
            expiredFiles.push(fileId);
            // Delete the actual file
            try {
                if (fs.existsSync(fileData.path)) {
                    fs.unlinkSync(fileData.path);
                }
            } catch (error) {
                console.error(`Error deleting expired file ${fileData.path}:`, error);
            }
        }
    }
    
    // Remove from database
    for (const fileId of expiredFiles) {
        fileDatabase.delete(fileId);
    }
    
    if (expiredFiles.length > 0) {
        saveDatabase(fileDatabase);
        console.log(`Cleaned up ${expiredFiles.length} expired files`);
    }
}

// Run cleanup on startup
cleanupExpiredFiles();

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadsDir);
    },
    filename: function (req, file, cb) {
        const uniqueName = `${uuidv4()}-${file.originalname}`;
        cb(null, uniqueName);
    }
});

const upload = multer({ 
    storage: storage,
    limits: {
        fileSize: 5 * 1024 * 1024 * 1024, // 5GB limit (business tier)
        fieldSize: 10 * 1024 * 1024, // 10MB for form fields
        files: 1 // Only allow 1 file per request
    }
});

<<<<<<< HEAD
// Increase timeout for large file uploads
app.use('/upload', (req, res, next) => {
    req.setTimeout(30 * 60 * 1000); // 30 minutes timeout
    res.setTimeout(30 * 60 * 1000); // 30 minutes timeout
    next();
});

=======
>>>>>>> 9b57587dd035c392806c41dbdf72d7e547627a5b
// Authentication Routes
app.post('/auth/signin', (req, res) => {
    try {
        const { email, password } = req.body;
        
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }
        
        const user = userDB.authenticateUser(email, password);
        if (!user) {
            return res.status(401).json({ error: 'Invalid email or password' });
        }
        
        res.json({
            success: true,
            user: user
        });
        
    } catch (error) {
        console.error('Sign in error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.post('/auth/signup', (req, res) => {
    try {
        const { email, password, name, phone } = req.body;
        
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }
        
        const result = userDB.createUser(email, password, name, phone);
        if (!result.success) {
            return res.status(400).json({ error: result.error });
        }
        
        res.json({
            success: true,
            user: result.user
        });
        
    } catch (error) {
        console.error('Sign up error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.post('/auth/update-email', (req, res) => {
    try {
        const { currentEmail, newEmail } = req.body;
        
        if (!currentEmail || !newEmail) {
            return res.status(400).json({ error: 'Current email and new email are required' });
        }
        
        const result = userDB.updateUserEmail(currentEmail, newEmail);
        if (!result.success) {
            return res.status(400).json({ error: result.error });
        }
        
        res.json({
            success: true,
            user: result.user
        });
        
    } catch (error) {
        console.error('Update email error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.post('/auth/update-password', (req, res) => {
    try {
        const { email, currentPassword, newPassword } = req.body;
        
        if (!email || !currentPassword || !newPassword) {
            return res.status(400).json({ error: 'Email, current password, and new password are required' });
        }
        
        const result = userDB.updateUserPassword(email, currentPassword, newPassword);
        if (!result.success) {
            return res.status(400).json({ error: result.error });
        }
        
        res.json({
            success: true,
            message: 'Password updated successfully'
        });
        
    } catch (error) {
        console.error('Update password error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.get('/auth/user/:email', (req, res) => {
    try {
        const { email } = req.params;
        const user = userDB.getUserByEmail(email);
        
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }
        
        res.json({
            success: true,
            user: user
        });
        
    } catch (error) {
        console.error('Get user error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.post('/auth/update-profile', (req, res) => {
    try {
        const { email, updates } = req.body;
        
        if (!email || !updates) {
            return res.status(400).json({ error: 'Email and updates are required' });
        }
        
        const result = userDB.updateUserProfile(email, updates);
        if (!result.success) {
            return res.status(400).json({ error: result.error });
        }
        
        res.json({
            success: true,
            user: result.user
        });
        
    } catch (error) {
        console.error('Update profile error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Admin endpoint to list all users (for debugging)
app.get('/admin/users', (req, res) => {
    try {
        const users = userDB.getAllUsers();
        res.json({
            success: true,
            users: users,
            totalCount: users.length
        });
    } catch (error) {
        console.error('Get users error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

<<<<<<< HEAD
// Generate pre-signed upload URL
app.post('/upload-url', (req, res) => {
    try {
        const { fileName, fileSize, subscriptionTier = 'free' } = req.body;

        if (!fileName || !fileSize) {
            return res.status(400).json({ error: 'File name and size are required' });
        }

        const tierConfig = SUBSCRIPTION_TIERS[subscriptionTier] || SUBSCRIPTION_TIERS.free;

        // Check file size against tier limits
        if (fileSize > tierConfig.maxFileSize) {
=======
// Routes
app.post('/upload', upload.single('file'), (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        // Get subscription tier (default to free)
        const subscriptionTier = req.headers['x-subscription-tier'] || 'free';
        const tierConfig = SUBSCRIPTION_TIERS[subscriptionTier] || SUBSCRIPTION_TIERS.free;

        // Check file size limit
        if (req.file.size > tierConfig.maxFileSize) {
>>>>>>> 9b57587dd035c392806c41dbdf72d7e547627a5b
            return res.status(413).json({ 
                error: `File too large. Maximum size for ${subscriptionTier} tier is ${Math.round(tierConfig.maxFileSize / (1024 * 1024))}MB`,
                upgradeRequired: true,
                currentTier: subscriptionTier,
                maxSize: tierConfig.maxFileSize
            });
        }

        const fileId = uuidv4();
<<<<<<< HEAD
        const s3Key = `${fileId}-${fileName}`;

        // Create file metadata (will be saved after successful upload)
=======
        const fileName = req.file.originalname;
        const fileSize = req.file.size;
        const filePath = req.file.path;
        const mimeType = req.file.mimetype;
        
        // Create file metadata
>>>>>>> 9b57587dd035c392806c41dbdf72d7e547627a5b
        const fileData = {
            id: fileId,
            originalName: fileName,
            size: fileSize,
<<<<<<< HEAD
            s3Key: s3Key,
            mimeType: 'application/octet-stream',
=======
            path: filePath,
            mimeType: mimeType,
>>>>>>> 9b57587dd035c392806c41dbdf72d7e547627a5b
            uploadDate: new Date(),
            expiresAt: new Date(Date.now() + tierConfig.maxExpiryDays * 24 * 60 * 60 * 1000),
            downloadCount: 0,
            isActive: true,
            subscriptionTier: subscriptionTier
        };

<<<<<<< HEAD
        // Generate pre-signed upload URL
        const uploadParams = {
            Bucket: BUCKET_NAME,
            Key: s3Key,
            ContentType: 'application/octet-stream',
            Expires: 3600 // URL expires in 1 hour
        };

        s3.getSignedUrl('putObject', uploadParams, (err, uploadUrl) => {
            if (err) {
                console.error('Error generating upload URL:', err);
                return res.status(500).json({ error: 'Failed to generate upload URL' });
            }

            // Store file metadata in database
            fileDatabase.set(fileId, fileData);
            saveDatabase(fileDatabase);

            res.json({
                success: true,
                fileId: fileId,
                uploadUrl: uploadUrl,
                fileName: fileName,
                fileSize: fileSize,
                expiresAt: fileData.expiresAt,
                subscriptionTier: subscriptionTier,
                features: tierConfig.features
            });
        });

    } catch (error) {
        console.error('Upload URL generation error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Confirm upload completion
app.post('/upload-complete', (req, res) => {
    try {
        const { fileId } = req.body;

        if (!fileId) {
            return res.status(400).json({ error: 'File ID is required' });
        }

        const fileData = fileDatabase.get(fileId);
        if (!fileData) {
            return res.status(404).json({ error: 'File not found' });
        }
=======
        // Store in database
        fileDatabase.set(fileId, fileData);
        saveDatabase(fileDatabase);
>>>>>>> 9b57587dd035c392806c41dbdf72d7e547627a5b

        // Generate download link
        const downloadLink = `${req.protocol}://${req.get('host')}/file/${fileId}`;

        res.json({
            success: true,
            fileId: fileId,
            downloadLink: downloadLink,
<<<<<<< HEAD
            fileName: fileData.originalName,
            fileSize: fileData.size,
            expiresAt: fileData.expiresAt,
            subscriptionTier: fileData.subscriptionTier
        });

    } catch (error) {
        console.error('Upload completion error:', error);
=======
            fileName: fileName,
            fileSize: fileSize,
            expiresAt: fileData.expiresAt,
            subscriptionTier: subscriptionTier,
            features: tierConfig.features
        });

    } catch (error) {
        console.error('Upload error:', error);
>>>>>>> 9b57587dd035c392806c41dbdf72d7e547627a5b
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.get('/file/:fileId', (req, res) => {
    try {
        const fileId = req.params.fileId;
        const fileData = fileDatabase.get(fileId);

        if (!fileData) {
            return res.status(404).json({ error: 'File not found' });
        }

        if (!fileData.isActive) {
            return res.status(410).json({ error: 'File has expired' });
        }

        if (new Date() > fileData.expiresAt) {
            fileData.isActive = false;
            saveDatabase(fileDatabase);
            return res.status(410).json({ error: 'File has expired' });
        }

        // Increment download count
        fileData.downloadCount++;
        saveDatabase(fileDatabase);

<<<<<<< HEAD
        // Generate pre-signed download URL for S3
        const downloadParams = {
            Bucket: BUCKET_NAME,
            Key: fileData.s3Key,
            Expires: 3600 // URL expires in 1 hour
        };

        s3.getSignedUrl('getObject', downloadParams, (err, downloadUrl) => {
            if (err) {
                console.error('Error generating download URL:', err);
                return res.status(500).json({ error: 'Error generating download link' });
            }

            res.json({
                success: true,
                downloadUrl: downloadUrl,
                fileName: fileData.originalName,
                fileSize: fileData.size,
                expiresAt: fileData.expiresAt
            });
=======
        // Check if file exists on disk
        if (!fs.existsSync(fileData.path)) {
            return res.status(404).json({ error: 'File not found on server' });
        }

        // Send file
        res.download(fileData.path, fileData.originalName, (err) => {
            if (err) {
                console.error('Download error:', err);
                res.status(500).json({ error: 'Error downloading file' });
            }
>>>>>>> 9b57587dd035c392806c41dbdf72d7e547627a5b
        });

    } catch (error) {
        console.error('Download error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.get('/file/:fileId/metadata', (req, res) => {
    try {
        const fileId = req.params.fileId;
        const fileData = fileDatabase.get(fileId);

        if (!fileData) {
            return res.status(404).json({ error: 'File not found' });
        }

        // Return file metadata without sensitive information
        res.json({
            id: fileData.id,
            originalName: fileData.originalName,
            size: fileData.size,
            mimeType: fileData.mimeType,
            uploadDate: fileData.uploadDate,
            expiresAt: fileData.expiresAt,
            downloadCount: fileData.downloadCount,
            isActive: fileData.isActive,
            subscriptionTier: fileData.subscriptionTier
        });

    } catch (error) {
        console.error('Metadata error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Subscription tiers endpoint
app.get('/subscription-tiers', (req, res) => {
    res.json({
        tiers: SUBSCRIPTION_TIERS,
        pricing: {
            free: { price: 0, currency: 'USD' },
            pro: { price: 4.99, currency: 'USD', period: 'month' },
            business: { price: 14.99, currency: 'USD', period: 'month' }
        }
    });
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Storage usage endpoint
app.get('/storage', (req, res) => {
    try {
        // Calculate total storage used
        let totalSize = 0;
        let fileCount = 0;
        
        for (const [fileId, fileData] of fileDatabase) {
            if (fileData.isActive && fs.existsSync(fileData.path)) {
                totalSize += fileData.size;
                fileCount++;
            }
        }
        
        // Get disk space info
        const stats = fs.statSync(uploadsDir);
        
        res.json({
            totalFiles: fileCount,
            totalSizeBytes: totalSize,
            totalSizeMB: Math.round((totalSize / (1024 * 1024)) * 100) / 100,
            totalSizeGB: Math.round((totalSize / (1024 * 1024 * 1024)) * 100) / 100,
            uploadsDirectory: uploadsDir,
            lastUpdated: new Date().toISOString()
        });
    } catch (error) {
        console.error('Storage check error:', error);
        res.status(500).json({ error: 'Error checking storage' });
    }
});

// List all files endpoint (for admin use)
app.get('/files', (req, res) => {
    try {
        const files = [];
        
        for (const [fileId, fileData] of fileDatabase) {
            if (fileData.isActive) {
                files.push({
                    id: fileId,
                    name: fileData.originalName,
                    size: fileData.size,
                    sizeMB: Math.round((fileData.size / (1024 * 1024)) * 100) / 100,
                    uploadDate: fileData.uploadDate,
                    expiresAt: fileData.expiresAt,
                    downloadCount: fileData.downloadCount,
                    subscriptionTier: fileData.subscriptionTier,
                    exists: fs.existsSync(fileData.path)
                });
            }
        }
        
        // Sort by upload date (newest first)
        files.sort((a, b) => new Date(b.uploadDate) - new Date(a.uploadDate));
        
        res.json({
            files: files,
            totalCount: files.length,
            lastUpdated: new Date().toISOString()
        });
    } catch (error) {
        console.error('Files list error:', error);
        res.status(500).json({ error: 'Error listing files' });
    }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`QuickSend API server running on port ${PORT}`);
    console.log(`Environment: ${NODE_ENV}`);
    console.log(`Upload endpoint: /upload`);
    console.log(`Download endpoint: /file/:fileId`);
    console.log(`Health check: /health`);
    console.log(`Database loaded with ${fileDatabase.size} files`);
    console.log(`Subscription tiers: ${Object.keys(SUBSCRIPTION_TIERS).join(', ')}`);
});

module.exports = app; 