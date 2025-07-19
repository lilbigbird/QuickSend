const AWS = require('aws-sdk');
const { Pool } = require('pg');
require('dotenv').config();

// AWS S3 Configuration
const s3 = new AWS.S3({
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    region: process.env.AWS_REGION || 'us-east-1'
});

// Database Configuration
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Storage monitoring class
class StorageMonitor {
    constructor() {
        this.bucketName = process.env.AWS_S3_BUCKET;
        this.costPerGB = 0.023; // S3 Standard storage cost per GB (us-east-1)
        this.costPerRequest = 0.0004; // S3 GET request cost per 1,000 requests
    }
    
    // Get S3 bucket usage statistics
    async getS3Usage() {
        try {
            console.log('📊 Analyzing S3 storage usage...');
            
            // List all objects in bucket
            const objects = [];
            let continuationToken = null;
            
            do {
                const params = {
                    Bucket: this.bucketName,
                    MaxKeys: 1000
                };
                
                if (continuationToken) {
                    params.ContinuationToken = continuationToken;
                }
                
                const response = await s3.listObjectsV2(params).promise();
                objects.push(...response.Contents);
                continuationToken = response.NextContinuationToken;
            } while (continuationToken);
            
            // Calculate storage metrics
            const totalSize = objects.reduce((sum, obj) => sum + obj.Size, 0);
            const totalFiles = objects.length;
            const averageFileSize = totalFiles > 0 ? totalSize / totalFiles : 0;
            
            // Calculate costs
            const storageCost = (totalSize / (1024 * 1024 * 1024)) * this.costPerGB;
            const estimatedMonthlyCost = storageCost * 30; // Rough estimate
            
            // Get storage by file type
            const fileTypes = {};
            objects.forEach(obj => {
                const extension = obj.Key.split('.').pop()?.toLowerCase() || 'unknown';
                if (!fileTypes[extension]) {
                    fileTypes[extension] = { count: 0, size: 0 };
                }
                fileTypes[extension].count++;
                fileTypes[extension].size += obj.Size;
            });
            
            return {
                totalSize,
                totalFiles,
                averageFileSize,
                storageCost,
                estimatedMonthlyCost,
                fileTypes,
                objects: objects.slice(0, 10) // First 10 objects for sample
            };
        } catch (error) {
            console.error('❌ Error getting S3 usage:', error);
            throw error;
        }
    }
    
    // Get database storage statistics
    async getDatabaseStats() {
        try {
            console.log('📊 Analyzing database usage...');
            
            // Get file statistics
            const fileStats = await pool.query(`
                SELECT 
                    COUNT(*) as total_files,
                    SUM(size) as total_size,
                    AVG(size) as avg_file_size,
                    COUNT(CASE WHEN status = 'uploaded' THEN 1 END) as uploaded_files,
                    COUNT(CASE WHEN status = 'uploading' THEN 1 END) as uploading_files,
                    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_files,
                    COUNT(CASE WHEN created_at >= NOW() - INTERVAL '24 hours' THEN 1 END) as files_last_24h,
                    COUNT(CASE WHEN created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as files_last_7d,
                    COUNT(CASE WHEN created_at >= NOW() - INTERVAL '30 days' THEN 1 END) as files_last_30d
                FROM files
            `);
            
            // Get user statistics
            const userStats = await pool.query(`
                SELECT 
                    COUNT(DISTINCT user_id) as total_users,
                    COUNT(DISTINCT CASE WHEN created_at >= NOW() - INTERVAL '24 hours' THEN user_id END) as active_users_24h,
                    COUNT(DISTINCT CASE WHEN created_at >= NOW() - INTERVAL '7 days' THEN user_id END) as active_users_7d
                FROM files
                WHERE user_id IS NOT NULL
            `);
            
            // Get largest files
            const largestFiles = await pool.query(`
                SELECT 
                    id,
                    original_name,
                    size,
                    created_at,
                    download_count
                FROM files 
                WHERE status = 'uploaded'
                ORDER BY size DESC 
                LIMIT 10
            `);
            
            return {
                fileStats: fileStats.rows[0],
                userStats: userStats.rows[0],
                largestFiles: largestFiles.rows
            };
        } catch (error) {
            console.error('❌ Error getting database stats:', error);
            throw error;
        }
    }
    
    // Generate storage report
    async generateReport() {
        console.log('🚀 QuickSend Storage Monitor');
        console.log('============================\n');
        
        try {
            const s3Usage = await this.getS3Usage();
            const dbStats = await this.getDatabaseStats();
            
            // Display S3 Storage Report
            console.log('📦 S3 STORAGE REPORT');
            console.log('===================');
            console.log(`Total Files: ${s3Usage.totalFiles.toLocaleString()}`);
            console.log(`Total Size: ${(s3Usage.totalSize / (1024 * 1024 * 1024)).toFixed(2)} GB`);
            console.log(`Average File Size: ${(s3Usage.averageFileSize / (1024 * 1024)).toFixed(2)} MB`);
            console.log(`Storage Cost: $${s3Usage.storageCost.toFixed(4)}/day`);
            console.log(`Estimated Monthly Cost: $${s3Usage.estimatedMonthlyCost.toFixed(2)}`);
            
            // Storage alerts
            const storageGB = s3Usage.totalSize / (1024 * 1024 * 1024);
            if (storageGB > 100) {
                console.log('⚠️  ALERT: Storage usage over 100GB - consider cleanup');
            }
            if (s3Usage.estimatedMonthlyCost > 50) {
                console.log('⚠️  ALERT: Monthly cost over $50 - consider optimization');
            }
            
            // File type breakdown
            console.log('\n📁 FILE TYPE BREAKDOWN');
            console.log('=====================');
            Object.entries(s3Usage.fileTypes)
                .sort(([,a], [,b]) => b.size - a.size)
                .slice(0, 10)
                .forEach(([type, stats]) => {
                    const sizeMB = stats.size / (1024 * 1024);
                    console.log(`${type}: ${stats.count} files, ${sizeMB.toFixed(2)} MB`);
                });
            
            // Database Report
            console.log('\n🗄️  DATABASE REPORT');
            console.log('==================');
            console.log(`Total Files in DB: ${dbStats.fileStats.total_files.toLocaleString()}`);
            console.log(`Uploaded Files: ${dbStats.fileStats.uploaded_files.toLocaleString()}`);
            console.log(`Failed Files: ${dbStats.fileStats.failed_files.toLocaleString()}`);
            console.log(`Files Last 24h: ${dbStats.fileStats.files_last_24h.toLocaleString()}`);
            console.log(`Files Last 7d: ${dbStats.fileStats.files_last_7d.toLocaleString()}`);
            console.log(`Files Last 30d: ${dbStats.fileStats.files_last_30d.toLocaleString()}`);
            
            if (dbStats.userStats.total_users > 0) {
                console.log(`Total Users: ${dbStats.userStats.total_users.toLocaleString()}`);
                console.log(`Active Users (24h): ${dbStats.userStats.active_users_24h.toLocaleString()}`);
                console.log(`Active Users (7d): ${dbStats.userStats.active_users_7d.toLocaleString()}`);
            }
            
            // Largest files
            console.log('\n📏 LARGEST FILES');
            console.log('===============');
            dbStats.largestFiles.forEach((file, index) => {
                const sizeMB = file.size / (1024 * 1024);
                console.log(`${index + 1}. ${file.original_name} (${sizeMB.toFixed(2)} MB, ${file.download_count} downloads)`);
            });
            
            // Recommendations
            console.log('\n💡 RECOMMENDATIONS');
            console.log('==================');
            
            if (s3Usage.totalFiles > 10000) {
                console.log('🔧 Consider implementing file lifecycle policies');
            }
            
            if (dbStats.fileStats.failed_files > 100) {
                console.log('🔧 Review failed uploads and implement better error handling');
            }
            
            if (s3Usage.estimatedMonthlyCost > 100) {
                console.log('💰 Consider S3 Intelligent Tiering for cost optimization');
            }
            
            if (dbStats.fileStats.files_last_30d > 10000) {
                console.log('📈 High growth detected - consider scaling database');
            }
            
            // Storage thresholds
            console.log('\n🎯 STORAGE THRESHOLDS');
            console.log('====================');
            console.log(`Current Usage: ${(storageGB).toFixed(2)} GB`);
            console.log(`Free Tier Limit: 5 GB (AWS S3)`);
            console.log(`Recommended Limit: 100 GB (before cost optimization)`);
            console.log(`Critical Limit: 1 TB (immediate action needed)`);
            
            return {
                s3Usage,
                dbStats,
                recommendations: {
                    needsCleanup: storageGB > 100,
                    needsOptimization: s3Usage.estimatedMonthlyCost > 50,
                    highGrowth: dbStats.fileStats.files_last_30d > 10000
                }
            };
            
        } catch (error) {
            console.error('❌ Error generating report:', error);
            throw error;
        } finally {
            await pool.end();
        }
    }
    
    // Clean up old files (optional)
    async cleanupOldFiles(daysOld = 30) {
        try {
            console.log(`🧹 Cleaning up files older than ${daysOld} days...`);
            
            const result = await pool.query(`
                SELECT id, s3_key, s3_bucket 
                FROM files 
                WHERE created_at < NOW() - INTERVAL '${daysOld} days'
                AND status = 'uploaded'
            `);
            
            console.log(`Found ${result.rows.length} files to clean up`);
            
            for (const file of result.rows) {
                try {
                    // Delete from S3
                    await s3.deleteObject({
                        Bucket: file.s3_bucket,
                        Key: file.s3_key
                    }).promise();
                    
                    // Delete from database
                    await pool.query('DELETE FROM files WHERE id = $1', [file.id]);
                    
                    console.log(`✅ Cleaned up file: ${file.id}`);
                } catch (error) {
                    console.log(`❌ Failed to clean up file ${file.id}: ${error.message}`);
                }
            }
            
            console.log('🧹 Cleanup completed!');
        } catch (error) {
            console.error('❌ Error during cleanup:', error);
        }
    }
}

// Run monitoring if this file is executed directly
if (require.main === module) {
    const monitor = new StorageMonitor();
    
    const args = process.argv.slice(2);
    if (args.includes('--cleanup')) {
        const days = parseInt(args[args.indexOf('--cleanup') + 1]) || 30;
        monitor.cleanupOldFiles(days);
    } else {
        monitor.generateReport();
    }
}

module.exports = StorageMonitor; 