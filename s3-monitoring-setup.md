# 🔔 S3 Storage Monitoring & Cost Alerts Setup Guide

## 🎯 **What You Need to Monitor:**

### **Storage Thresholds:**
- **5 GB** - Free tier limit (start monitoring)
- **50 GB** - $1.15/month (warning level)
- **100 GB** - $2.30/month (action level)
- **500 GB** - $11.50/month (critical level)

### **Cost Thresholds:**
- **$5/month** - Early warning
- **$10/month** - Monitor closely
- **$25/month** - Take action
- **$50/month** - Critical - implement cleanup

---

## 🚀 **Step-by-Step Setup (No AWS Experience Required)**

### **Step 1: Access AWS Console**
1. Go to [aws.amazon.com](https://aws.amazon.com)
2. Click "Sign In to the Console"
3. Use your existing AWS credentials (from QuickSend setup)

### **Step 2: Set Up Billing Alerts (Most Important!)**

#### **A. Go to Billing Dashboard:**
1. In AWS Console, search for "Billing" in the search bar
2. Click "Billing and Cost Management" → "Billing and Cost Management home"

#### **B. Create Cost Alerts:**
**Option 1: Using Billing Preferences**
1. Scroll down to "Preferences and Settings" in the left sidebar
2. Click "Billing Preferences"
3. Look for "Cost and usage reports" section
4. Click "Create alert"

**Option 2: Using Budgets (Recommended)**
1. Scroll down to "Budgets and Planning" in the left sidebar
2. Click "Budgets"
3. Click "Create budget"
4. Choose "Cost budget"

**Option 3: Using Cost Anomaly Detection (Best for automatic monitoring)**
1. Scroll down to "Cost and Usage Analysis" in the left sidebar
2. Click "Cost Anomaly Detection"
3. Click "Create monitor"
4. This automatically detects unusual spending patterns

Set up these alerts:

```
Alert 1: Early Warning
- Amount: $5
- Period: Monthly
- Email: your-email@example.com

Alert 2: Monitor Level
- Amount: $10
- Period: Monthly
- Email: your-email@example.com

Alert 3: Action Level
- Amount: $25
- Period: Monthly
- Email: your-email@example.com

Alert 4: Critical Level
- Amount: $50
- Period: Monthly
- Email: your-email@example.com
```

### **Step 3: Set Up S3 Storage Monitoring**

#### **A. Go to S3 Console:**
1. In AWS Console, search for "S3"
2. Click "S3" → "Buckets"
3. Click on your bucket: `quicksend-files-sour`

#### **B. Enable Storage Monitoring:**
1. Click on your bucket name
2. Go to "Metrics" tab
3. Click "Create metric filter"
4. Set up these metrics:

```
Metric 1: Storage Usage
- Filter: All objects
- Metric: Total size
- Threshold: 5 GB (free tier)

Metric 2: Object Count
- Filter: All objects  
- Metric: Number of objects
- Threshold: 1000 objects
```

### **Step 4: Set Up CloudWatch Alarms**

#### **A. Go to CloudWatch:**
1. In AWS Console, search for "CloudWatch"
2. Click "CloudWatch" → "Alarms"

#### **B. Create Storage Alarms:**
1. Click "Create alarm"
2. Select "S3" as the service
3. Create these alarms:

```
Alarm 1: Storage Usage Warning
- Metric: BucketSizeBytes
- Threshold: 5 GB
- Period: 1 hour
- Actions: Send email notification

Alarm 2: Storage Usage Critical
- Metric: BucketSizeBytes  
- Threshold: 50 GB
- Period: 1 hour
- Actions: Send email notification

Alarm 3: Object Count Warning
- Metric: NumberOfObjects
- Threshold: 1000 objects
- Period: 1 hour
- Actions: Send email notification
```

### **Step 5: Set Up SNS Notifications**

#### **A. Create SNS Topic:**
1. In AWS Console, search for "SNS"
2. Click "SNS" → "Topics"
3. Click "Create topic"
4. Name: `quicksend-storage-alerts`
5. Click "Create topic"

#### **B. Subscribe Your Email:**
1. Click on your topic
2. Click "Create subscription"
3. Protocol: Email
4. Endpoint: your-email@example.com
5. Click "Create subscription"
6. **Important:** Check your email and confirm the subscription!

---

## 📊 **Automated Monitoring Script**

I've created a script that checks your storage and sends you alerts:

```bash
# Run this weekly to monitor storage
node storage-monitor.js

# This will show you:
# - Current storage usage
# - Estimated monthly cost
# - File count and types
# - Recommendations
```

### **Set Up Automated Monitoring:**

#### **Option A: Weekly Email Report**
1. Add this to your calendar: "Check QuickSend storage"
2. Run: `node storage-monitor.js`
3. Review the results

#### **Option B: Automated Script (Advanced)**
```bash
# Create a cron job to run weekly
# On Mac/Linux, add to crontab:
0 9 * * 1 cd /path/to/quicksend && node storage-monitor.js
```

---

## 🔧 **Quick Setup Commands**

### **One-Click Setup (Using AWS CLI):**

If you have AWS CLI installed, run these commands:

```bash
# Install AWS CLI if you don't have it
# Download from: https://aws.amazon.com/cli/

# Configure AWS CLI with your credentials
aws configure

# Set up billing alerts
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "QuickSend Storage Monitor",
    "MonitorType": "DIMENSIONAL",
    "DimensionalValueCount": 10
  }'

# Set up S3 bucket monitoring
aws s3api put-bucket-metrics-configuration \
  --bucket quicksend-files-sour \
  --id storage-monitor \
  --metrics-configuration '{
    "Id": "storage-monitor",
    "Filter": {
      "Prefix": ""
    }
  }'
```

---

## 📱 **Mobile Notifications**

### **AWS Mobile App:**
1. Download "AWS Console" app from App Store/Play Store
2. Sign in with your AWS credentials
3. Enable push notifications for:
   - Billing alerts
   - CloudWatch alarms
   - S3 storage warnings

### **Email Notifications:**
- All alerts will be sent to your email
- Check spam folder if you don't receive them
- Reply to confirm subscription emails

---

## 🎯 **What You'll Receive:**

### **Email Alerts:**
```
Subject: AWS Billing Alert - $10 threshold exceeded

Hello,

Your AWS account has exceeded the $10 billing threshold.
Current charges: $12.45
Storage usage: 45.2 GB
Files: 1,234 objects

View details: https://console.aws.amazon.com/billing
```

### **Storage Monitor Output:**
```
📦 S3 STORAGE REPORT
===================
Total Files: 1,234
Total Size: 45.2 GB
Storage Cost: $1.04/day
Estimated Monthly Cost: $31.20

⚠️  ALERT: Storage usage over 45GB - consider cleanup
```

---

## 🛠️ **Emergency Actions When Alerts Trigger:**

### **If Storage > 50GB:**
1. Run cleanup: `node storage-monitor.js --cleanup 30`
2. Delete old files older than 30 days
3. Consider implementing lifecycle policies

### **If Cost > $25/month:**
1. Review largest files: Check storage-monitor.js output
2. Implement S3 Intelligent Tiering
3. Consider file compression
4. Review user upload patterns

### **If Object Count > 1000:**
1. Implement file lifecycle policies
2. Set up automatic cleanup for old files
3. Consider archiving strategy

---

## 💡 **Pro Tips:**

### **Cost Optimization:**
1. **Start with free tier** - 5GB storage, 20K requests/month
2. **Monitor weekly** - Use storage-monitor.js
3. **Set up alerts early** - Don't wait until you hit limits
4. **Implement cleanup** - Remove old files automatically

### **Best Practices:**
1. **Check alerts daily** - Review any notifications
2. **Monitor growth trends** - Watch for unusual spikes
3. **Plan for scaling** - Have cleanup strategies ready
4. **Document thresholds** - Keep track of your limits

---

## 🚨 **Emergency Contacts:**

### **If You Need Help:**
- **AWS Support**: Available in AWS Console
- **Documentation**: [AWS S3 Pricing](https://aws.amazon.com/s3/pricing/)
- **Community**: [AWS Forums](https://forums.aws.amazon.com/)

### **Quick Commands:**
```bash
# Check current usage
node storage-monitor.js

# Clean up old files
node storage-monitor.js --cleanup 30

# Get detailed cost breakdown
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 --granularity MONTHLY --metrics BlendedCost
```

---

## ✅ **Setup Checklist:**

- [ ] Set up billing alerts ($5, $10, $25, $50)
- [ ] Configure S3 storage monitoring
- [ ] Create CloudWatch alarms
- [ ] Set up SNS email notifications
- [ ] Test storage-monitor.js script
- [ ] Subscribe to AWS mobile app notifications
- [ ] Document your thresholds and procedures

**Once you complete this setup, you'll get automatic notifications before you ever have to worry about unexpected costs!** 🎉 