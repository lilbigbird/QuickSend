const AWS = require('aws-sdk');
const readline = require('readline');
require('dotenv').config();

// Configure AWS
AWS.config.update({
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    region: process.env.AWS_REGION || 'us-east-2'
});

const cloudwatch = new AWS.CloudWatch();
const sns = new AWS.SNS();
const s3 = new AWS.S3();

// Create readline interface for user input
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// Helper function to get user input
function askQuestion(question) {
    return new Promise((resolve) => {
        rl.question(question, (answer) => {
            resolve(answer);
        });
    });
}

// Set up SNS topic for notifications
async function setupSNSTopic(email) {
    try {
        console.log('📧 Setting up SNS topic for notifications...');
        
        // Create SNS topic
        const topicResult = await sns.createTopic({
            Name: 'quicksend-storage-alerts'
        }).promise();
        
        const topicArn = topicResult.TopicArn;
        console.log(`✅ Created SNS topic: ${topicArn}`);
        
        // Subscribe email to topic
        const subscribeResult = await sns.subscribe({
            TopicArn: topicArn,
            Protocol: 'email',
            Endpoint: email
        }).promise();
        
        console.log(`✅ Subscribed ${email} to notifications`);
        console.log('📧 Check your email and confirm the subscription!');
        
        return topicArn;
    } catch (error) {
        console.error('❌ Error setting up SNS:', error.message);
        return null;
    }
}

// Set up CloudWatch alarms
async function setupCloudWatchAlarms(topicArn) {
    try {
        console.log('🔔 Setting up CloudWatch alarms...');
        
        const bucketName = process.env.AWS_S3_BUCKET || 'quicksend-files-sour';
        
        // Alarm 1: Storage usage warning (5GB)
        await cloudwatch.putMetricAlarm({
            AlarmName: 'QuickSend-Storage-Warning',
            AlarmDescription: 'Storage usage approaching free tier limit',
            MetricName: 'BucketSizeBytes',
            Namespace: 'AWS/S3',
            Statistic: 'Average',
            Period: 3600, // 1 hour
            EvaluationPeriods: 1,
            Threshold: 5 * 1024 * 1024 * 1024, // 5GB in bytes
            ComparisonOperator: 'GreaterThanThreshold',
            Dimensions: [
                {
                    Name: 'BucketName',
                    Value: bucketName
                },
                {
                    Name: 'StorageType',
                    Value: 'StandardStorage'
                }
            ],
            AlarmActions: topicArn ? [topicArn] : []
        }).promise();
        
        console.log('✅ Created storage warning alarm (5GB)');
        
        // Alarm 2: Storage usage critical (50GB)
        await cloudwatch.putMetricAlarm({
            AlarmName: 'QuickSend-Storage-Critical',
            AlarmDescription: 'Storage usage critical - take action',
            MetricName: 'BucketSizeBytes',
            Namespace: 'AWS/S3',
            Statistic: 'Average',
            Period: 3600, // 1 hour
            EvaluationPeriods: 1,
            Threshold: 50 * 1024 * 1024 * 1024, // 50GB in bytes
            ComparisonOperator: 'GreaterThanThreshold',
            Dimensions: [
                {
                    Name: 'BucketName',
                    Value: bucketName
                },
                {
                    Name: 'StorageType',
                    Value: 'StandardStorage'
                }
            ],
            AlarmActions: topicArn ? [topicArn] : []
        }).promise();
        
        console.log('✅ Created storage critical alarm (50GB)');
        
        // Alarm 3: Object count warning (1000 objects)
        await cloudwatch.putMetricAlarm({
            AlarmName: 'QuickSend-ObjectCount-Warning',
            AlarmDescription: 'High number of objects in bucket',
            MetricName: 'NumberOfObjects',
            Namespace: 'AWS/S3',
            Statistic: 'Average',
            Period: 3600, // 1 hour
            EvaluationPeriods: 1,
            Threshold: 1000,
            ComparisonOperator: 'GreaterThanThreshold',
            Dimensions: [
                {
                    Name: 'BucketName',
                    Value: bucketName
                }
            ],
            AlarmActions: topicArn ? [topicArn] : []
        }).promise();
        
        console.log('✅ Created object count warning alarm (1000 objects)');
        
    } catch (error) {
        console.error('❌ Error setting up CloudWatch alarms:', error.message);
    }
}

// Enable S3 metrics
async function enableS3Metrics() {
    try {
        console.log('📊 Enabling S3 metrics...');
        
        const bucketName = process.env.AWS_S3_BUCKET || 'quicksend-files-sour';
        
        // Enable metrics for the bucket
        await s3.putBucketMetricsConfiguration({
            Bucket: bucketName,
            Id: 'storage-monitor',
            MetricsConfiguration: {
                Id: 'storage-monitor',
                Filter: {
                    Prefix: ''
                }
            }
        }).promise();
        
        console.log('✅ Enabled S3 metrics for storage monitoring');
        
    } catch (error) {
        console.error('❌ Error enabling S3 metrics:', error.message);
    }
}

// Test current storage
async function testCurrentStorage() {
    try {
        console.log('📊 Testing current storage...');
        
        const bucketName = process.env.AWS_S3_BUCKET || 'quicksend-files-sour';
        
        // List objects to get current usage
        const objects = await s3.listObjectsV2({
            Bucket: bucketName,
            MaxKeys: 1000
        }).promise();
        
        const totalSize = objects.Contents.reduce((sum, obj) => sum + obj.Size, 0);
        const totalFiles = objects.Contents.length;
        
        console.log(`📦 Current Storage:`);
        console.log(`   Files: ${totalFiles}`);
        console.log(`   Size: ${(totalSize / (1024 * 1024 * 1024)).toFixed(2)} GB`);
        console.log(`   Estimated monthly cost: $${(totalSize / (1024 * 1024 * 1024) * 0.023).toFixed(2)}`);
        
        if (totalSize > 5 * 1024 * 1024 * 1024) {
            console.log('⚠️  Storage is over 5GB - you may incur charges');
        } else {
            console.log('✅ Storage is within free tier limits');
        }
        
    } catch (error) {
        console.error('❌ Error testing storage:', error.message);
    }
}

// Main setup function
async function setupS3Monitoring() {
    console.log('🚀 QuickSend S3 Monitoring Setup');
    console.log('================================\n');
    
    // Check if AWS credentials are configured
    if (!process.env.AWS_ACCESS_KEY_ID || !process.env.AWS_SECRET_ACCESS_KEY) {
        console.log('❌ AWS credentials not found in environment variables');
        console.log('Please make sure your .env file contains:');
        console.log('AWS_ACCESS_KEY_ID=your_access_key');
        console.log('AWS_SECRET_ACCESS_KEY=your_secret_key');
        console.log('AWS_S3_BUCKET=quicksend-files-sour');
        return;
    }
    
    try {
        // Get user email
        const email = await askQuestion('📧 Enter your email for notifications: ');
        
        if (!email || !email.includes('@')) {
            console.log('❌ Please enter a valid email address');
            rl.close();
            return;
        }
        
        console.log('\n🔧 Setting up S3 monitoring and alerts...\n');
        
        // Test current storage
        await testCurrentStorage();
        console.log('');
        
        // Set up SNS topic
        const topicArn = await setupSNSTopic(email);
        console.log('');
        
        // Enable S3 metrics
        await enableS3Metrics();
        console.log('');
        
        // Set up CloudWatch alarms
        await setupCloudWatchAlarms(topicArn);
        console.log('');
        
        console.log('🎉 S3 Monitoring Setup Complete!');
        console.log('===============================');
        console.log('✅ SNS topic created for notifications');
        console.log('✅ CloudWatch alarms configured');
        console.log('✅ S3 metrics enabled');
        console.log('');
        console.log('📧 Next steps:');
        console.log('1. Check your email and confirm the SNS subscription');
        console.log('2. Set up billing alerts in AWS Console (see s3-monitoring-setup.md)');
        console.log('3. Run "node storage-monitor.js" weekly to check usage');
        console.log('');
        console.log('🔔 You will now receive alerts when:');
        console.log('   - Storage exceeds 5GB (warning)');
        console.log('   - Storage exceeds 50GB (critical)');
        console.log('   - Object count exceeds 1000');
        console.log('');
        console.log('📊 To check current usage anytime:');
        console.log('   node storage-monitor.js');
        
    } catch (error) {
        console.error('❌ Setup failed:', error.message);
    } finally {
        rl.close();
    }
}

// Run setup if this file is executed directly
if (require.main === module) {
    setupS3Monitoring();
}

module.exports = { setupS3Monitoring }; 