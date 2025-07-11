# QuickSend iOS App

This is the native iOS version of QuickSend, built with Swift and UIKit. The app allows users to quickly upload files and generate shareable links.

## Features

- **File Selection**: Choose files from the Files app or photo library
- **File Upload**: Upload files to the QuickSend backend
- **Link Generation**: Generate shareable download links
- **Link Sharing**: Copy links or share via native iOS share sheet
- **Modern UI**: Clean, intuitive interface following iOS design guidelines

## Project Structure

```
QuickSend/
├── AppDelegate.swift              # Main app delegate
├── SceneDelegate.swift            # Scene lifecycle management
├── Info.plist                     # App configuration
├── ViewControllers/
│   └── HomeViewController.swift   # Main file upload interface
├── Services/
│   └── NetworkService.swift       # API communication layer
├── Models/                        # Data models (future)
├── Views/                         # Custom UI components (future)
├── Utils/                         # Utility classes (future)
└── Resources/                     # Assets and resources (future)
```

## Requirements

- iOS 14.0+
- Xcode 12.0+
- Swift 5.0+
- Backend server running (see backend README)

## Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd QuickSend/ios
   ```

2. **Open in Xcode**:
   - Open `QuickSend.xcodeproj` in Xcode
   - Or create a new Xcode project and add the Swift files

3. **Configure the backend URL**:
   - Open `Services/NetworkService.swift`
   - Update the `baseURL` property to point to your backend server
   - Default: `http://localhost:3000`

4. **Build and run**:
   - Select your target device or simulator
   - Press Cmd+R to build and run

## API Integration

The app communicates with the QuickSend backend API:

- **Upload**: `POST /upload` - Upload a file and get a shareable link
- **Download**: `GET /file/:fileId` - Download a file using its ID
- **Metadata**: `GET /file/:fileId/metadata` - Get file information
- **Health**: `GET /health` - Check API status

## Development Phases

### Phase 1: Foundation ✅
- [x] Backend API setup
- [x] iOS project structure
- [x] Basic UI implementation

### Phase 2: Core Functionality (Current)
- [x] File selection and upload
- [x] Link generation and display
- [x] Network service implementation

### Phase 3: Power User Features (Future)
- [ ] User authentication
- [ ] Dashboard for file management
- [ ] Push notifications

### Phase 4: Polish & Deployment (Future)
- [ ] Settings screen
- [ ] Error handling improvements
- [ ] App Store preparation

## Architecture

The app follows the MVC (Model-View-Controller) pattern:

- **Models**: Data structures for API responses
- **Views**: UI components and layouts
- **Controllers**: Business logic and user interaction
- **Services**: Network communication and external APIs

## Key Components

### HomeViewController
The main interface that handles:
- File selection via UIDocumentPickerViewController
- File upload to backend
- Link display and sharing
- User feedback and error handling

### NetworkService
Singleton service that manages:
- HTTP requests to the backend API
- File upload with multipart form data
- Response parsing and error handling
- JSON decoding for API responses

## Testing

To test the app:

1. **Start the backend server**:
   ```bash
   cd ../backend
   npm run dev
   ```

2. **Run the iOS app** in Xcode

3. **Test file upload**:
   - Tap "Tap to Select File"
   - Choose a file from the Files app
   - Tap "Generate Link"
   - Verify the link is generated and can be shared

## Troubleshooting

### Common Issues

1. **Network errors**: Ensure the backend server is running and accessible
2. **File upload fails**: Check file size limits and network connectivity
3. **Build errors**: Verify all Swift files are added to the Xcode project

### Debug Mode

The app includes comprehensive error handling and logging. Check the Xcode console for detailed error messages during development.

## Contributing

1. Follow the existing code style and architecture
2. Add appropriate error handling for new features
3. Test thoroughly on both simulator and physical devices
4. Update documentation for any API changes

## License

This project is part of the QuickSend application suite. 