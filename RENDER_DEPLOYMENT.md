# QuickSend Render Deployment Guide

This guide provides step-by-step instructions for deploying QuickSend to Render with optimized S3 integration for 100+ concurrent users.

## 🚀 **Render Deployment Steps**

### **1. Prerequisites**
- Render account (free tier available)
- AWS S3 bucket configured
- PostgreSQL database (Render PostgreSQL or external)
- Redis instance (Render Redis or external)

### **2. Render Service Setup**

#### **Create Web Service**
1. **Go to Render Dashboard**: https://dashboard.render.com
2. **Click "New +"** → **"Web Service"**
3. **Connect Repository**: Link your GitHub QuickSend repository
4. **Configure Service**:
   ```
   Name: quicksend-api
   Environment: Node
   Build Command: cd backend && npm install
   Start Command: cd backend && npm start
   Instance Type: Standard-1X (recommended for 100+ users)
   ```

#### **Environment Variables**
Add these environment variables in Render dashboard:

```bash
# Server Configuration
NODE_ENV=production
PORT=10000

# Database (Render PostgreSQL)
DATABASE_URL=postgresql://user:pass@host:5432/quicksend

# Redis (Render Redis or external)
REDIS_URL=redis://user:pass@host:6379

# AWS S3 Configuration
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1
S3_BUCKET_NAME=quicksend-files

# Security
JWT_SECRET=your_super_secret_jwt_key
ALLOWED_ORIGINS=https://quicksend.app,https://your-app-name.onrender.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=2000

# Performance
WORKER_PROCESSES=auto
CONNECTION_POOL_SIZE=50

# Render-specific
RENDER_EXTERNAL_URL=https://your-app-name.onrender.com
RENDER_INSTANCE_TYPE=standard-1x
```

### **3. S3 Bucket Configuration**

#### **Create S3 Bucket**
1. **AWS Console** → **S3** → **Create Bucket**
2. **Bucket Name**: `quicksend-files`
3. **Region**: Choose closest to your users
4. **Block Public Access**: Keep enabled (we use presigned URLs)

#### **S3 Bucket Policy**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowQuickSendAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::YOUR_ACCOUNT_ID:user/YOUR_IAM_USER"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::quicksend-files/*"
        }
    ]
}
```

#### **S3 CORS Configuration**
```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
        "AllowedOrigins": ["*"],
        "ExposeHeaders": ["ETag"]
    }
]
```

### **4. Database Setup**

#### **Option A: Render PostgreSQL (Recommended)**
1. **Create PostgreSQL Service** in Render
2. **Database Name**: `quicksend`
3. **User**: Auto-generated
4. **Password**: Auto-generated
5. **Copy connection string** to environment variables

#### **Option B: External PostgreSQL**
- Use your existing PostgreSQL instance
- Ensure it's accessible from Render's IP ranges

### **5. Redis Setup**

#### **Option A: Render Redis (Recommended)**
1. **Create Redis Service** in Render
2. **Plan**: Free tier (for testing) or paid plan (for production)
3. **Copy connection string** to environment variables

#### **Option B: External Redis**
- Use Redis Cloud, AWS ElastiCache, or your own Redis instance
- Ensure it's accessible from Render

### **6. Deploy and Test**

#### **Automatic Deployment**
1. **Push to GitHub**: Your changes will auto-deploy
2. **Monitor Build**: Check build logs in Render dashboard
3. **Verify Health**: Test health endpoint

#### **Test Endpoints**
```bash
# Health check
curl https://your-app-name.onrender.com/health

# Test upload (replace with your actual file)
curl -X POST -F "file=@test.txt" https://your-app-name.onrender.com/upload

# Test download (replace with actual fileId)
curl https://your-app-name.onrender.com/download/YOUR_FILE_ID
```

## 🔧 **S3 Optimization for Render**

### **Why S3 is Perfect for Render:**

#### **1. Serverless File Storage**
- **No server storage**: Files stored in S3, not on Render
- **Unlimited storage**: S3 scales automatically
- **High availability**: 99.99% uptime guarantee
- **Global CDN**: CloudFront integration available

#### **2. Performance Benefits**
- **Direct downloads**: Users download directly from S3
- **Reduced server load**: Render servers handle only metadata
- **Parallel uploads**: Multiple files upload simultaneously
- **Presigned URLs**: Secure, time-limited access

#### **3. Cost Optimization**
- **Pay per use**: Only pay for storage and transfers
- **No server storage costs**: Render doesn't charge for file storage
- **Efficient bandwidth**: Direct S3 downloads reduce Render bandwidth

### **S3 Performance for 100+ Users:**

| Metric | S3 Capability | Render Integration |
|--------|---------------|-------------------|
| **Concurrent Uploads** | Unlimited | 100+ simultaneous |
| **Upload Speed** | 5Gbps per connection | 10MB/s per user |
| **Download Speed** | 5Gbps per connection | 50MB/s per user |
| **File Size** | 5TB max | 5GB per file |
| **Storage Cost** | $0.023/GB/month | Minimal |
| **Transfer Cost** | $0.09/GB | Pay per use |

### **S3 Optimization Features:**

#### **1. Multipart Uploads**
```javascript
// Automatic for files > 100MB
const s3UploadManager = new AWS.S3.ManagedUpload({
    partSize: 10 * 1024 * 1024, // 10MB parts
    queueSize: 4, // 4 concurrent parts
    leavePartsOnError: false
});
```

#### **2. Presigned URLs**
```javascript
// Direct S3 access for downloads
const presignedUrl = await s3.getSignedUrlPromise('getObject', {
    Bucket: S3_BUCKET_NAME,
    Key: s3Key,
    Expires: 3600 // 1 hour
});
```

#### **3. Retry Logic**
```javascript
// Automatic retry with exponential backoff
const uploadWithRetry = async (retries = 3) => {
    for (let attempt = 1; attempt <= retries; attempt++) {
        try {
            return await s3.upload(uploadParams).promise();
        } catch (error) {
            if (attempt === retries) throw error;
            await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
        }
    }
};
```

## 📊 **Monitoring & Scaling**

### **Render Monitoring**
- **Uptime**: 99.9%+ with automatic restarts
- **Performance**: Real-time metrics in dashboard
- **Logs**: Centralized logging and error tracking
- **Auto-scaling**: Automatic scaling based on demand

### **S3 Monitoring**
- **CloudWatch**: Monitor S3 usage and performance
- **Cost tracking**: Monitor storage and transfer costs
- **Access logs**: Track file access patterns
- **Error tracking**: Monitor failed uploads/downloads

### **Health Checks**
```bash
# Comprehensive health check
curl https://your-app-name.onrender.com/health

# Expected response:
{
  "status": "healthy",
  "worker": 12345,
  "files": 1500,
  "memory": {
    "rss": 512,
    "heapUsed": 256,
    "heapTotal": 1024
  },
  "uptime": 86400,
  "responseTime": "45ms",
  "redis": "connected",
  "database": "connected"
}
```

## 🚀 **Production Checklist**

### **Before Going Live:**
- [ ] **SSL Certificate**: Render provides automatic SSL
- [ ] **Custom Domain**: Configure custom domain in Render
- [ ] **Environment Variables**: All production values set
- [ ] **Database Backups**: Enable automatic backups
- [ ] **Monitoring**: Set up alerts and monitoring
- [ ] **Rate Limiting**: Configure appropriate limits
- [ ] **Security**: Review security headers and CORS

### **Performance Testing:**
```bash
# Load test with Artillery
npm install -g artillery

# Create load-test.yml
artillery run load-test.yml
```

### **Cost Optimization:**
- **S3 Lifecycle**: Set up automatic file deletion after expiry
- **CDN**: Enable CloudFront for global distribution
- **Compression**: Enable S3 compression for text files
- **Monitoring**: Track usage to optimize costs

## 🔒 **Security Best Practices**

### **S3 Security:**
- **IAM Roles**: Use IAM roles instead of access keys
- **Bucket Policies**: Restrict access to specific users
- **Encryption**: Enable server-side encryption
- **Versioning**: Enable versioning for file recovery

### **Render Security:**
- **Environment Variables**: Never commit secrets to git
- **HTTPS Only**: Force HTTPS in production
- **CORS**: Restrict allowed origins
- **Rate Limiting**: Prevent abuse and DDoS

---

**Your QuickSend app is now optimized for Render deployment with enterprise-grade S3 integration! 🚀** 