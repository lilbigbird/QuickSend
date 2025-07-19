const axios = require('axios');
const fs = require('fs');
const path = require('path');

// Configuration for 1000 user simulation
const BASE_URL = 'https://api.quicksend.vip';
const TOTAL_USERS = 1000;
const BATCH_SIZE = 50; // Process in batches to avoid overwhelming
const TEST_FILE_SIZE = 1024 * 1024; // 1MB test file
const DELAY_BETWEEN_BATCHES = 1000; // 1 second between batches

// Create test file
function createTestFile() {
    const testData = Buffer.alloc(TEST_FILE_SIZE, 'A');
    const testFilePath = path.join(__dirname, 'test-file-large.txt');
    fs.writeFileSync(testFilePath, testData);
    return testFilePath;
}

// Simulate a single user uploading a file
async function simulateUserUpload(userId, testFilePath) {
    try {
        const fileName = `user-${userId}-test.txt`;
        const stats = fs.statSync(testFilePath);
        
        // Step 1: Get upload URL
        const uploadUrlResponse = await axios.post(`${BASE_URL}/s3/upload-url`, {
            fileName: fileName,
            fileType: 'text/plain',
            fileSize: stats.size
        }, {
            timeout: 30000,
            headers: {
                'User-Agent': `QuickSend-Test-User-${userId}`
            }
        });
        
        if (!uploadUrlResponse.data.url) {
            throw new Error(`Failed to get upload URL: ${JSON.stringify(uploadUrlResponse.data)}`);
        }
        
        const { url: presignedUrl, fileId } = uploadUrlResponse.data;
        
        // Step 2: Upload to S3
        const fileBuffer = fs.readFileSync(testFilePath);
        await axios.put(presignedUrl, fileBuffer, {
            headers: {
                'Content-Type': 'text/plain',
                'Content-Length': stats.size
            },
            timeout: 60000, // 60 seconds for upload
            maxContentLength: Infinity,
            maxBodyLength: Infinity
        });
        
        // Step 3: Notify completion
        await axios.post(`${BASE_URL}/s3/upload-complete`, {
            fileId: fileId,
            fileSize: stats.size
        }, {
            timeout: 10000
        });
        
        return { success: true, fileId, userId };
        
    } catch (error) {
        return { 
            success: false, 
            userId, 
            error: error.message,
            status: error.response?.status,
            data: error.response?.data
        };
    }
}

// Process users in batches
async function processBatch(startIndex, endIndex, testFilePath) {
    const promises = [];
    
    for (let i = startIndex; i < endIndex; i++) {
        const promise = simulateUserUpload(i + 1, testFilePath);
        promises.push(promise);
    }
    
    return await Promise.all(promises);
}

// Main load test for 1000 users
async function run1000UserLoadTest() {
    console.log('🚀 QuickSend 1000 User Load Test');
    console.log('==================================\n');
    
    const testFilePath = createTestFile();
    const startTime = Date.now();
    
    console.log(`📊 Testing ${TOTAL_USERS} users uploading files simultaneously`);
    console.log(`📁 Test file size: ${(TEST_FILE_SIZE / (1024 * 1024)).toFixed(2)} MB`);
    console.log(`⚡ Processing in batches of ${BATCH_SIZE} users\n`);
    
    const allResults = [];
    const totalBatches = Math.ceil(TOTAL_USERS / BATCH_SIZE);
    
    for (let batch = 0; batch < totalBatches; batch++) {
        const startIndex = batch * BATCH_SIZE;
        const endIndex = Math.min(startIndex + BATCH_SIZE, TOTAL_USERS);
        
        console.log(`🔄 Processing batch ${batch + 1}/${totalBatches} (users ${startIndex + 1}-${endIndex})`);
        
        const batchStartTime = Date.now();
        const batchResults = await processBatch(startIndex, endIndex, testFilePath);
        const batchDuration = Date.now() - batchStartTime;
        
        const batchSuccessful = batchResults.filter(r => r.success).length;
        const batchFailed = batchResults.filter(r => !r.success).length;
        
        console.log(`   ✅ Successful: ${batchSuccessful}/${batchResults.length}`);
        console.log(`   ❌ Failed: ${batchFailed}/${batchResults.length}`);
        console.log(`   ⏱️  Batch duration: ${batchDuration}ms`);
        console.log(`   🚀 Average: ${batchDuration / batchResults.length}ms per user\n`);
        
        allResults.push(...batchResults);
        
        // Add delay between batches to avoid overwhelming the server
        if (batch < totalBatches - 1) {
            console.log(`⏳ Waiting ${DELAY_BETWEEN_BATCHES}ms before next batch...\n`);
            await new Promise(resolve => setTimeout(resolve, DELAY_BETWEEN_BATCHES));
        }
    }
    
    const totalDuration = Date.now() - startTime;
    const totalSuccessful = allResults.filter(r => r.success).length;
    const totalFailed = allResults.filter(r => !r.success).length;
    
    // Clean up test file
    fs.unlinkSync(testFilePath);
    
    // Display final results
    console.log('📊 FINAL RESULTS');
    console.log('================');
    console.log(`Total Users: ${TOTAL_USERS}`);
    console.log(`✅ Successful Uploads: ${totalSuccessful}/${TOTAL_USERS} (${((totalSuccessful/TOTAL_USERS)*100).toFixed(1)}%)`);
    console.log(`❌ Failed Uploads: ${totalFailed}/${TOTAL_USERS} (${((totalFailed/TOTAL_USERS)*100).toFixed(1)}%)`);
    console.log(`⏱️  Total Duration: ${totalDuration}ms (${(totalDuration/1000).toFixed(1)}s)`);
    console.log(`🚀 Average Time per User: ${(totalDuration/TOTAL_USERS).toFixed(1)}ms`);
    console.log(`📈 Throughput: ${(TOTAL_USERS/(totalDuration/1000)).toFixed(1)} users/second`);
    
    // Analyze failures
    if (totalFailed > 0) {
        console.log('\n🔍 FAILURE ANALYSIS');
        console.log('==================');
        
        const errorTypes = {};
        allResults.filter(r => !r.success).forEach(result => {
            const errorKey = result.status || result.error.split(':')[0];
            errorTypes[errorKey] = (errorTypes[errorKey] || 0) + 1;
        });
        
        Object.entries(errorTypes).forEach(([error, count]) => {
            console.log(`   ${error}: ${count} failures`);
        });
    }
    
    // Recommendations
    console.log('\n💡 RECOMMENDATIONS');
    console.log('==================');
    
    if (totalSuccessful === TOTAL_USERS) {
        console.log('✅ Your app can handle 1000+ concurrent users!');
        console.log('🚀 Ready for production scaling');
    } else if (totalSuccessful >= TOTAL_USERS * 0.95) {
        console.log('⚠️  Your app handles most concurrent users well');
        console.log('🔧 Consider minor optimizations for edge cases');
    } else if (totalSuccessful >= TOTAL_USERS * 0.8) {
        console.log('⚠️  Your app needs optimization for high concurrency');
        console.log('🔧 Consider:');
        console.log('   - Increasing database connection pool');
        console.log('   - Adding Redis caching');
        console.log('   - Implementing request queuing');
    } else {
        console.log('❌ Your app needs significant optimization');
        console.log('🔧 Consider:');
        console.log('   - Scaling database infrastructure');
        console.log('   - Adding load balancers');
        console.log('   - Implementing microservices');
    }
    
    console.log('\n📊 MONITORING TIPS');
    console.log('==================');
    console.log('- Monitor database connections during peak load');
    console.log('- Watch for memory usage spikes');
    console.log('- Track S3 upload success rates');
    console.log('- Monitor API response times');
    
    return {
        totalUsers: TOTAL_USERS,
        successful: totalSuccessful,
        failed: totalFailed,
        duration: totalDuration,
        throughput: TOTAL_USERS/(totalDuration/1000),
        successRate: (totalSuccessful/TOTAL_USERS)*100
    };
}

// Run the test if this file is executed directly
if (require.main === module) {
    run1000UserLoadTest().catch(console.error);
}

module.exports = { run1000UserLoadTest }; 