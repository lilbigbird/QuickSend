const axios = require('axios');
const fs = require('fs');
const path = require('path');

// Configuration
const BASE_URL = 'https://api.quicksend.vip';
const CONCURRENT_DOWNLOADS = 10;
const CONCURRENT_UPLOADS = 3; // Reduced to avoid rate limits
const TEST_FILE_SIZE = 1024 * 1024; // 1MB test file

// Create test file
function createTestFile() {
    const testData = Buffer.alloc(TEST_FILE_SIZE, 'A');
    const testFilePath = path.join(__dirname, 'test-file.txt');
    fs.writeFileSync(testFilePath, testData);
    return testFilePath;
}

// Test multiple simultaneous downloads
async function testConcurrentDownloads(fileId) {
    console.log(`\n🧪 Testing ${CONCURRENT_DOWNLOADS} simultaneous downloads...`);
    
    const startTime = Date.now();
    const promises = [];
    
    for (let i = 0; i < CONCURRENT_DOWNLOADS; i++) {
        const promise = axios.get(`${BASE_URL}/download/${fileId}`, {
            timeout: 30000,
            maxRedirects: 5
        }).then(response => {
            console.log(`✅ Download ${i + 1} completed successfully`);
            return { success: true, index: i + 1 };
        }).catch(error => {
            console.log(`❌ Download ${i + 1} failed: ${error.message}`);
            return { success: false, index: i + 1, error: error.message };
        });
        
        promises.push(promise);
    }
    
    const results = await Promise.all(promises);
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    const successful = results.filter(r => r.success).length;
    const failed = results.filter(r => !r.success).length;
    
    console.log(`\n📊 Download Test Results:`);
    console.log(`   ✅ Successful: ${successful}/${CONCURRENT_DOWNLOADS}`);
    console.log(`   ❌ Failed: ${failed}/${CONCURRENT_DOWNLOADS}`);
    console.log(`   ⏱️  Duration: ${duration}ms`);
    console.log(`   🚀 Average: ${duration / CONCURRENT_DOWNLOADS}ms per download`);
    
    return { successful, failed, duration };
}

// Test multiple simultaneous uploads
async function testConcurrentUploads() {
    console.log(`\n🧪 Testing ${CONCURRENT_UPLOADS} simultaneous uploads...`);
    
    const testFilePath = createTestFile();
    const startTime = Date.now();
    const promises = [];
    
    // Add delay between requests to avoid rate limiting
    for (let i = 0; i < CONCURRENT_UPLOADS; i++) {
        const promise = new Promise(async (resolve) => {
            // Add small delay between requests
            await new Promise(r => setTimeout(r, i * 100));
            const result = await uploadTestFile(testFilePath, i + 1);
            resolve(result);
        });
        promises.push(promise);
    }
    
    const results = await Promise.all(promises);
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    const successful = results.filter(r => r.success).length;
    const failed = results.filter(r => !r.success).length;
    
    console.log(`\n📊 Upload Test Results:`);
    console.log(`   ✅ Successful: ${successful}/${CONCURRENT_UPLOADS}`);
    console.log(`   ❌ Failed: ${failed}/${CONCURRENT_UPLOADS}`);
    console.log(`   ⏱️  Duration: ${duration}ms`);
    console.log(`   🚀 Average: ${duration / CONCURRENT_UPLOADS}ms per upload`);
    
    // Clean up test file
    fs.unlinkSync(testFilePath);
    
    return { successful, failed, duration, fileIds: results.filter(r => r.success).map(r => r.fileId) };
}

// Helper function to upload a test file
async function uploadTestFile(filePath, index) {
    try {
        // Step 1: Get upload URL
        const stats = fs.statSync(filePath);
        const fileName = `test-file-${index}.txt`;
        
        const uploadUrlResponse = await axios.post(`${BASE_URL}/s3/upload-url`, {
            fileName: fileName,
            fileType: 'text/plain',
            fileSize: stats.size
        });
        
        console.log(`📤 Upload ${index} - Response status: ${uploadUrlResponse.status}`);
        console.log(`📤 Upload ${index} - Response data:`, uploadUrlResponse.data);
        
        if (!uploadUrlResponse.data.success && !uploadUrlResponse.data.url) {
            throw new Error(`Failed to get upload URL: ${JSON.stringify(uploadUrlResponse.data)}`);
        }
        
        const { url: presignedUrl, fileId } = uploadUrlResponse.data;
        
        // Step 2: Upload to S3
        const fileBuffer = fs.readFileSync(filePath);
        await axios.put(presignedUrl, fileBuffer, {
            headers: {
                'Content-Type': 'text/plain',
                'Content-Length': stats.size
            },
            timeout: 30000
        });
        
        // Step 3: Notify completion
        await axios.post(`${BASE_URL}/s3/upload-complete`, {
            fileId: fileId,
            fileSize: stats.size
        });
        
        console.log(`✅ Upload ${index} completed successfully (File ID: ${fileId})`);
        return { success: true, fileId, index };
        
    } catch (error) {
        console.log(`❌ Upload ${index} failed: ${error.message}`);
        return { success: false, index, error: error.message };
    }
}

// Test server health and limits
async function testServerHealth() {
    console.log('\n🏥 Testing server health...');
    
    try {
        const response = await axios.get(`${BASE_URL}/health`, { timeout: 5000 });
        console.log(`✅ Server health: ${response.status}`);
        console.log(`📊 Response time: ${response.headers['x-response-time'] || 'N/A'}`);
        return true;
    } catch (error) {
        console.log(`❌ Server health check failed: ${error.message}`);
        return false;
    }
}

// Main test function
async function runLoadTests() {
    console.log('🚀 QuickSend Load Testing Suite');
    console.log('================================');
    
    // Test server health first
    const serverHealthy = await testServerHealth();
    if (!serverHealthy) {
        console.log('\n❌ Server is not healthy. Aborting tests.');
        return;
    }
    
    // Test concurrent uploads
    const uploadResults = await testConcurrentUploads();
    
    if (uploadResults.successful > 0) {
        // Test concurrent downloads with the first successful upload
        const testFileId = uploadResults.fileIds[0];
        await testConcurrentDownloads(testFileId);
    }
    
    console.log('\n🎉 Load testing completed!');
    console.log('\n📋 Recommendations:');
    
    if (uploadResults.successful === CONCURRENT_UPLOADS) {
        console.log('   ✅ Your app can handle multiple simultaneous uploads');
    } else {
        console.log('   ⚠️  Consider optimizing upload handling for high concurrency');
    }
    
    console.log('   📊 Monitor your server logs for any errors during high load');
    console.log('   🔧 Consider implementing rate limiting for production');
}

// Run tests if this file is executed directly
if (require.main === module) {
    runLoadTests().catch(console.error);
}

module.exports = { runLoadTests, testConcurrentDownloads, testConcurrentUploads }; 