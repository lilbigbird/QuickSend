# QuickSend Backend API

This is the backend API for the QuickSend iOS application, providing file upload, storage, and sharing capabilities.

## Features

- File upload with automatic link generation
- File download with metadata tracking
- Link expiration (7 days by default)
- Download count tracking
- Health check endpoint

## Setup

1. Install dependencies:
```bash
npm install
```

2. Copy environment configuration:
```bash
cp env.example .env
```

3. Update the `.env` file with your configuration values.

4. Start the development server:
```bash
npm run dev
```

The server will start on `http://localhost:3000` by default.

## API Endpoints

### Upload File
**POST** `/upload`

Upload a file and receive a shareable link.

**Request:**
- Content-Type: `multipart/form-data`
- Body: `file` field containing the file to upload

**Response:**
```json
{
  "success": true,
  "fileId": "uuid-string",
  "downloadLink": "http://localhost:3000/file/uuid-string",
  "fileName": "example.pdf",
  "fileSize": 1024,
  "expiresAt": "2024-01-15T10:30:00.000Z"
}
```

### Download File
**GET** `/file/:fileId`

Download a file using its unique ID.

**Response:**
- File download with original filename
- 404 if file not found
- 410 if file has expired

### Get File Metadata
**GET** `/file/:fileId/metadata`

Get metadata about a file without downloading it.

**Response:**
```json
{
  "id": "uuid-string",
  "originalName": "example.pdf",
  "size": 1024,
  "mimeType": "application/pdf",
  "uploadDate": "2024-01-08T10:30:00.000Z",
  "expiresAt": "2024-01-15T10:30:00.000Z",
  "downloadCount": 5,
  "isActive": true
}
```

### Health Check
**GET** `/health`

Check if the API is running.

**Response:**
```json
{
  "status": "OK",
  "timestamp": "2024-01-08T10:30:00.000Z"
}
```

## Configuration

### Environment Variables

- `PORT`: Server port (default: 3000)
- `NODE_ENV`: Environment (development/production)
- `MAX_FILE_SIZE`: Maximum file size in bytes (default: 100MB)
- `FILE_EXPIRY_DAYS`: Days until file expires (default: 7)

## Development

### File Storage

Currently, files are stored locally in the `uploads/` directory. In production, this should be replaced with cloud storage (AWS S3, Google Cloud Storage, etc.).

### Database

Currently, file metadata is stored in memory. In production, this should be replaced with a proper database (PostgreSQL, MongoDB, etc.).

### Security

- File size limits are enforced
- Files are stored with unique names to prevent conflicts
- Expired files are automatically marked as inactive

## Production Considerations

1. **File Storage**: Implement cloud storage (AWS S3, Google Cloud Storage)
2. **Database**: Use PostgreSQL or MongoDB for file metadata
3. **Caching**: Implement Redis for session management and caching
4. **Authentication**: Add user authentication and authorization
5. **Rate Limiting**: Implement rate limiting for upload/download endpoints
6. **Monitoring**: Add logging and monitoring (Winston, Sentry)
7. **SSL**: Use HTTPS in production
8. **CDN**: Use a CDN for file delivery

## Testing

To test the API endpoints, you can use tools like:
- Postman
- curl
- Thunder Client (VS Code extension)

Example curl command for file upload:
```bash
curl -X POST -F "file=@/path/to/your/file.pdf" http://localhost:3000/upload
``` 