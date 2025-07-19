#!/usr/bin/env node

const https = require('https');

const API_URL = 'https://api.quicksend.vip';

async function testEndpoint(endpoint) {
    return new Promise((resolve, reject) => {
        const req = https.get(`${API_URL}${endpoint}`, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const json = JSON.parse(data);
                    resolve({ statusCode: res.statusCode, data: json });
                } catch (e) {
                    resolve({ statusCode: res.statusCode, data: data });
                }
            });
        });
        
        req.on('error', (err) => {
            reject(err);
        });
        
        req.setTimeout(10000, () => {
            req.destroy();
            reject(new Error('Timeout'));
        });
    });
}

async function testKeepAlive() {
    console.log('🧪 Testing QuickSend API Keep-Alive...\n');
    
    const endpoints = [
        { path: '/', name: 'Root Endpoint' },
        { path: '/health', name: 'Health Endpoint' },
        { path: '/keepalive-status', name: 'Keep-Alive Status' }
    ];
    
    for (const endpoint of endpoints) {
        try {
            console.log(`📡 Testing ${endpoint.name}...`);
            const result = await testEndpoint(endpoint.path);
            console.log(`✅ ${endpoint.name}: ${result.statusCode}`);
            console.log(`   Response: ${JSON.stringify(result.data, null, 2)}`);
            console.log('');
        } catch (error) {
            console.log(`❌ ${endpoint.name}: ${error.message}`);
            console.log('');
        }
    }
    
    console.log('🎯 Keep-alive test completed!');
    console.log('💡 The server should stay active with pings every 8 minutes.');
}

// Run the test
testKeepAlive().catch(console.error); 