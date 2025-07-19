# QuickSend - File Sharing Made Simple

QuickSend is a modern file sharing application that allows users to quickly upload files and generate shareable download links. The project consists of a Node.js backend API and a native iOS application with subscription-based tiers.

## 🚀 Features

- **Instant File Upload**: Upload files with progress tracking
- **Automatic Link Generation**: Get shareable download links instantly
- **Subscription Tiers**: Free, Pro, and Business plans with different limits
- **Native iOS Experience**: Clean, intuitive interface following iOS design guidelines
- **Cross-Platform Sharing**: Share links via Messages, Mail, or any app
- **Account Management**: User authentication and subscription management

## 📱 Screenshots

*Screenshots will be added once the app is running*

## 🏗️ Architecture

```
QuickSend/
├── QuickSend/          # iOS App (Swift/UIKit)
│   ├── ViewControllers/
│   ├── Services/
│   ├── Models/
│   └── Resources/
└── backend/            # Node.js API Server
    ├── server.js       # Main server file
    ├── userDatabase.js # User management
    └── package.json    # Dependencies
```

## 🛠️ Technology Stack

### Backend
- **Node.js** with Express.js
- **AWS S3** for file storage
- **UUID** for unique file identification
- **CORS** for cross-origin requests
- **dotenv** for environment configuration

### iOS App
- **Swift 5.0+** with UIKit
- **URLSession** for network communication
- **UIDocumentPickerViewController** for file selection
- **UIActivityViewController** for native sharing
- **Auto Layout** for responsive design

## 📋 Prerequisites

- Node.js 16+ (18+ recommended)
- Xcode 12.0+
- iOS 14.0+ (for testing)
- Git
- AWS S3 bucket

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd QuickSend
```

### 2. Start the Backend Server
```bash
cd backend
npm install
cp env.example .env
# Add your AWS credentials to .env
npm start
```

The backend will start on `http://localhost:3000`

### 3. Open the iOS Project
```bash
# Open QuickSend.xcodeproj in Xcode
```

### 4. Configure the iOS App
- Open `Services/NetworkService.swift`
- Verify the `baseURL` points to your backend

### 5. Build and Run
- Select your target device or simulator in Xcode
- Press Cmd+R to build and run

## 📖 Usage

### For End Users
1. **Select a File**: Tap the "Tap to Select File" area
2. **Choose File**: Select from Files app or photo library
3. **Generate Link**: Tap "Generate Link" to upload and get a shareable link
4. **Share**: Copy the link or use the native share sheet

## 🔧 Subscription Tiers

- **Free**: 100MB files, 7-day expiry, 10 uploads/month
- **Pro**: 1GB files, 30-day expiry, 100 uploads/month
- **Business**: 5GB files, 90-day expiry, 1000 uploads/month

## 🔒 Security Considerations

- Files are stored with unique names to prevent conflicts
- Automatic file expiration based on subscription tier
- File size limits enforced per subscription tier
- HTTPS required for production deployment

## 🚀 Production Deployment

### Backend
- Deployed on Render (free tier)
- Configure environment variables in Render dashboard
- Automatic deployment on push to main branch

### iOS App
- Configure production backend URL
- Add app icons and launch screen
- Test on physical devices
- Submit to App Store

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)

## License

Private project - All rights reserved
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Check the individual README files in `backend/` and `ios/`
- Review the API documentation in the backend README
- Test with the provided curl commands

## 🗺️ Roadmap

- [ ] User accounts and authentication
- [ ] File management dashboard
- [ ] Push notifications
- [ ] Advanced sharing options
- [ ] Web interface
- [ ] Android app
- [ ] Desktop applications

---

**QuickSend** - Making file sharing as simple as possible. 
>>>>>>> 9b57587dd035c392806c41dbdf72d7e547627a5b
