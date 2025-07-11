<<<<<<< HEAD
# QuickSend

A native iOS app for secure file sharing with subscription-based tiers and cloud storage.

## Project Structure

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

## Features

### iOS App
- Native Swift/UIKit interface
- File selection and upload
- Progress tracking for large files
- Subscription management
- Account settings
- Direct S3 uploads for performance

### Backend API
- User authentication
- S3 pre-signed URL generation
- File metadata management
- Subscription tier enforcement
- File expiration handling

## Subscription Tiers

- **Free**: 100MB files, 7-day expiry, 10 uploads/month
- **Pro**: 1GB files, 30-day expiry, 100 uploads/month
- **Business**: 5GB files, 90-day expiry, 1000 uploads/month

## Technology Stack

- **Frontend**: Swift, UIKit, iOS 15+
- **Backend**: Node.js, Express
- **Storage**: AWS S3
- **Deployment**: Render (free tier)

## Setup

### Backend
1. Navigate to `backend/` directory
2. Install dependencies: `npm install`
3. Create `.env` file with AWS credentials
4. Start server: `npm start`

### iOS App
1. Open `QuickSend.xcodeproj` in Xcode
2. Update `NetworkService.swift` with your backend URL
3. Build and run on device/simulator

## Environment Variables

Create a `.env` file in the `backend/` directory:

```env
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
S3_BUCKET_NAME=your_bucket_name
PORT=3000
NODE_ENV=development
```

## Deployment

The backend is configured for deployment on Render:
- Connect this repository to Render
- Set environment variables in Render dashboard
- Deploy automatically on push to main branch

## License

Private project - All rights reserved 
=======
# QuickSend - File Sharing Made Simple

QuickSend is a modern file sharing application that allows users to quickly upload files and generate shareable download links. The project consists of a Node.js backend API and a native iOS application.

## 🚀 Features

- **Instant File Upload**: Upload files up to 100MB with a simple tap
- **Automatic Link Generation**: Get shareable download links instantly
- **Link Expiration**: Files automatically expire after 7 days
- **Native iOS Experience**: Clean, intuitive interface following iOS design guidelines
- **Cross-Platform Sharing**: Share links via Messages, Mail, or any app
- **No Account Required**: Start sharing files immediately

## 📱 Screenshots

*Screenshots will be added once the app is running*

## 🏗️ Architecture

```
QuickSend/
├── backend/           # Node.js API server
│   ├── server.js      # Main Express server
│   ├── package.json   # Dependencies
│   └── README.md      # Backend documentation
├── ios/              # Native iOS application
│   ├── QuickSend/    # Swift source code
│   └── README.md     # iOS documentation
└── README.md         # This file
```

## 🛠️ Technology Stack

### Backend
- **Node.js** with Express.js
- **Multer** for file upload handling
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
npm run dev
```

The backend will start on `http://localhost:3000`

### 3. Open the iOS Project
```bash
cd ios
# Open QuickSend.xcodeproj in Xcode
# Or create a new Xcode project and add the Swift files
```

### 4. Configure the iOS App
- Open `Services/NetworkService.swift`
- Verify the `baseURL` points to your backend (default: `http://localhost:3000`)

### 5. Build and Run
- Select your target device or simulator in Xcode
- Press Cmd+R to build and run

## 📖 Usage

### For End Users
1. **Select a File**: Tap the "Tap to Select File" area
2. **Choose File**: Select from Files app or photo library
3. **Generate Link**: Tap "Generate Link" to upload and get a shareable link
4. **Share**: Copy the link or use the native share sheet

### For Developers
See the individual README files in `backend/` and `ios/` directories for detailed development documentation.

## 🔧 Development Phases

### ✅ Phase 1: Foundation (Complete)
- [x] Backend API with file upload/download endpoints
- [x] iOS project structure and basic UI
- [x] File selection and upload functionality

### 🔄 Phase 2: Core Functionality (Current)
- [x] Network service implementation
- [x] Link generation and display
- [x] Native iOS sharing integration

### 📋 Phase 3: Power User Features (Planned)
- [ ] User authentication with Firebase
- [ ] Dashboard for file management
- [ ] Push notifications for downloads
- [ ] File metadata and analytics

### 🎯 Phase 4: Polish & Deployment (Planned)
- [ ] Settings and preferences screen
- [ ] Enhanced error handling
- [ ] App Store submission preparation
- [ ] Production deployment

## 🧪 Testing

### Backend Testing
```bash
cd backend
curl -X POST -F "file=@/path/to/test/file.txt" http://localhost:3000/upload
```

### iOS Testing
1. Start the backend server
2. Run the iOS app in Xcode
3. Test file upload and link generation
4. Verify sharing functionality

## 🔒 Security Considerations

- Files are stored with unique names to prevent conflicts
- Automatic file expiration after 7 days
- File size limits enforced (100MB)
- HTTPS required for production deployment

## 🚀 Production Deployment

### Backend
- Deploy to cloud platform (Heroku, AWS, Google Cloud)
- Configure environment variables
- Set up cloud storage (AWS S3, Google Cloud Storage)
- Implement proper database (PostgreSQL, MongoDB)

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
