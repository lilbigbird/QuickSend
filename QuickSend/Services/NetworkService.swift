import Foundation
import UIKit
import ObjectiveC

class NetworkService {
    static let shared = NetworkService()
    
    // For development (local testing)
    // private let baseURL = "http://192.168.1.30:3000" // Your Mac's IP address for real device
    
    // For production (App Store)
    private let baseURL = "https://api.quicksend.vip" // Your custom domain
    
    // Optimized URLSession configuration for high concurrency
    private lazy var optimizedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes
        configuration.timeoutIntervalForResource = 600 // 10 minutes
        configuration.httpMaximumConnectionsPerHost = 10 // Allow multiple concurrent connections
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil // Disable cache for file uploads
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return URLSession(configuration: configuration)
    }()
    
    // Background session for large file uploads
    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.quicksend.background")
        configuration.timeoutIntervalForRequest = 600 // 10 minutes
        configuration.timeoutIntervalForResource = 3600 // 1 hour
        configuration.httpMaximumConnectionsPerHost = 5
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }()
    
    // Operation queue for managing concurrent operations
    private let operationQueue = OperationQueue()
    
    private init() {
        // Configure operation queue for optimal concurrency
        operationQueue.maxConcurrentOperationCount = 5
        operationQueue.qualityOfService = .userInitiated
    }
    
    // MARK: - Concurrent Upload Manager
    private var activeUploads: [String: URLSessionUploadTask] = [:]
    private let uploadQueue = DispatchQueue(label: "com.quicksend.upload", qos: .userInitiated, attributes: .concurrent)
    
    // MARK: - Optimized S3 Upload (Direct to S3)
    func uploadFileOptimized(fileURL: URL, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        let fileName = fileURL.lastPathComponent
        let fileType = getMimeType(for: fileURL) ?? "application/octet-stream"
        
        print("📤 Starting optimized upload for file: \(fileName)")
        print("📤 File type: \(fileType)")
        
        // Step 1: Get presigned upload URL from backend
        getS3UploadURL(fileName: fileName, fileType: fileType) { [weak self] result in
            switch result {
            case .success(let s3Response):
                print("✅ Got presigned URL for file: \(fileName)")
                // Step 2: Upload directly to S3 using presigned URL
                guard let presignedURL = URL(string: s3Response.url) else {
                    print("❌ Invalid presigned URL")
                    completion(.failure(.invalidURL))
                    return
                }
                
                self?.uploadFileToS3(fileURL: fileURL, presignedURL: presignedURL, progressHandler: progressHandler) { uploadResult in
                    switch uploadResult {
                    case .success:
                        print("✅ S3 upload successful for file: \(fileName)")
                        
                        // Step 3: Get file size and confirm upload
                        let fileSize = self?.getFileSize(fileURL: fileURL) ?? 0
                        self?.confirmS3Upload(fileId: s3Response.fileId, fileSize: Int(fileSize)) { confirmResult in
                            switch confirmResult {
                            case .success:
                                print("✅ Upload confirmed for file: \(fileName)")
                                // Step 4: Create UploadResponse for compatibility
                                let uploadResponse = UploadResponse(
                                    success: true,
                                    fileId: s3Response.fileId,
                                    downloadLink: "https://api.quicksend.vip/download/\(s3Response.fileId)",
                                    fileName: fileName,
                                    fileSize: fileSize,
                                    expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 60 * 60))
                                )
                                completion(.success(uploadResponse))
                            case .failure(let error):
                                print("⚠️ Upload confirmation failed for file: \(fileName), but upload was successful")
                                // Still return success since the file was uploaded to S3
                                let uploadResponse = UploadResponse(
                                    success: true,
                                    fileId: s3Response.fileId,
                                    downloadLink: "https://api.quicksend.vip/download/\(s3Response.fileId)",
                                    fileName: fileName,
                                    fileSize: fileSize,
                                    expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 60 * 60))
                                )
                                completion(.success(uploadResponse))
                            }
                        }
                    case .failure(let error):
                        print("❌ S3 upload failed for file: \(fileName), error: \(error)")
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                print("❌ Failed to get presigned URL for file: \(fileName), error: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // Helper function to get MIME type
    private func getMimeType(for url: URL) -> String? {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "mp3":
            return "audio/mpeg"
        case "zip":
            return "application/zip"
        case "rar":
            return "application/x-rar-compressed"
        default:
            return nil
        }
    }
    
    // Helper function to get file size
    private func getFileSize(fileURL: URL) -> Int64 {
        if fileURL.startAccessingSecurityScopedResource() {
            defer { fileURL.stopAccessingSecurityScopedResource() }
            
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                return Int64(resourceValues.fileSize ?? 0)
            }
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
                return attributes[.size] as? Int64 ?? 0
            }
        } else {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                return Int64(resourceValues.fileSize ?? 0)
            }
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
                return attributes[.size] as? Int64 ?? 0
            }
        }
        
        return 0
    }
    
    // Confirm S3 upload and update file metadata
    private func confirmS3Upload(fileId: String, fileSize: Int, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/s3/upload-complete") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fileId": fileId,
            "fileSize": fileSize
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("📤 Confirming upload for fileId: \(fileId), size: \(fileSize)")
        } catch {
            completion(.failure(.encodingError))
            return
        }
        
        let task = optimizedSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Upload confirmation error: \(error)")
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Upload confirmation failed: \(responseString)")
                    }
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                print("✅ Upload confirmation successful")
                completion(.success(()))
            }
        }
        
        task.resume()
    }
    
    // MARK: - File Upload (S3) with Concurrency Management (Legacy method)
    func uploadFile(fileURL: URL, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        let uploadId = UUID().uuidString
        
        // Add to active uploads
        uploadQueue.async(flags: .barrier) {
            self.activeUploads[uploadId] = nil // Will be set when task is created
        }
        guard let url = URL(string: "\(baseURL)/upload") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Get file size for progress tracking
        let fileSize: Int64
        if fileURL.startAccessingSecurityScopedResource() {
            defer { fileURL.stopAccessingSecurityScopedResource() }
            
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                fileSize = Int64(resourceValues.fileSize ?? 0)
            } else if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
                fileSize = attributes[.size] as? Int64 ?? 0
            } else {
                fileSize = 0
            }
        } else {
            // Fallback for non-security-scoped URLs
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                fileSize = Int64(resourceValues.fileSize ?? 0)
            } else if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
                fileSize = attributes[.size] as? Int64 ?? 0
            } else {
                fileSize = 0
            }
        }
        
        // Create multipart body
        var body = Data()
        
        // Add file header
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        
        // Add file data
        do {
            let fileData = try Data(contentsOf: fileURL)
            body.append(fileData)
        } catch {
            completion(.failure(.networkError(error)))
            return
        }
        
        // Add closing boundary
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create a custom URLSession with progress tracking
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes
        configuration.timeoutIntervalForResource = 600 // 10 minutes
        let session = URLSession(configuration: configuration)
        
        // Use optimized session for better concurrency
        let task = optimizedSession.uploadTask(with: request, from: body) { [weak self] data, response, error in
            // Remove from active uploads
            self?.uploadQueue.async(flags: .barrier) {
                self?.activeUploads.removeValue(forKey: uploadId)
            }
            
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
                    completion(.success(uploadResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        // Store task in active uploads
        uploadQueue.async(flags: .barrier) {
            self.activeUploads[uploadId] = task
        }
        
        // Monitor upload progress
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                progressHandler(Float(progress.fractionCompleted))
            }
        }
        
        // Store observation to prevent deallocation
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        task.resume()
    }
    
    // MARK: - Upload Management
    func cancelAllUploads() {
        uploadQueue.async(flags: .barrier) {
            for (_, task) in self.activeUploads {
                task.cancel()
            }
            self.activeUploads.removeAll()
        }
    }
    
    func getActiveUploadCount() -> Int {
        var count = 0
        uploadQueue.sync {
            count = self.activeUploads.count
        }
        return count
    }
    
    func cancelUpload(withId uploadId: String) {
        uploadQueue.async(flags: .barrier) {
            if let task = self.activeUploads[uploadId] {
                task.cancel()
                self.activeUploads.removeValue(forKey: uploadId)
            }
        }
    }
    
    // MARK: - S3 Presigned URL Methods
    func getS3UploadURL(fileName: String, fileType: String, completion: @escaping (Result<S3UploadURLResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/s3/upload-url") else {
            print("❌ Invalid URL: \(baseURL)/s3/upload-url")
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token if available
        if let token = UserManager.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔐 Using authentication token")
        } else {
            print("👤 No authentication token available")
        }
        
        let body: [String: Any] = [
            "fileName": fileName,
            "fileType": fileType
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("📤 Request body: \(body)")
        } catch {
            print("❌ Failed to encode request body: \(error)")
            completion(.failure(.encodingError))
            return
        }
        
        let task = optimizedSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Network error: \(error)")
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    completion(.failure(.invalidResponse))
                    return
                }
                
                print("📤 Response status: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response: \(responseString)")
                    }
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    print("❌ No response data")
                    completion(.failure(.noData))
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📤 Response data: \(responseString)")
                }
                
                do {
                    let response = try JSONDecoder().decode(S3UploadURLResponse.self, from: data)
                    print("✅ Successfully decoded S3 upload URL response")
                    completion(.success(response))
                } catch {
                    print("❌ Failed to decode response: \(error)")
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    func getS3DownloadURL(s3Key: String, completion: @escaping (Result<S3DownloadURLResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/s3/download-url") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication token if available
        if let token = UserManager.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "s3Key": s3Key
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.encodingError))
            return
        }
        
        let task = optimizedSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(S3DownloadURLResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Direct S3 Upload/Download
    func uploadFileToS3(fileURL: URL, presignedURL: URL, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        print("📤 Starting S3 upload to: \(presignedURL)")
        print("📤 File URL: \(fileURL)")
        
        let task = optimizedSession.uploadTask(with: request, fromFile: fileURL) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ S3 upload error: \(error)")
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    completion(.failure(.invalidResponse))
                    return
                }
                
                print("📤 S3 upload response status: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📤 S3 upload response data: \(responseString)")
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("❌ S3 upload failed with status: \(httpResponse.statusCode)")
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                print("✅ S3 upload completed successfully")
                completion(.success(()))
            }
        }
        
        // Monitor upload progress
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                progressHandler(Float(progress.fractionCompleted))
            }
        }
        
        // Store observation to prevent deallocation
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        task.resume()
    }
    
    func downloadFileFromS3(presignedURL: URL, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<Data, NetworkError>) -> Void) {
        let task = optimizedSession.dataTask(with: presignedURL) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                completion(.success(data))
            }
        }
        
        // Monitor download progress
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                progressHandler(Float(progress.fractionCompleted))
            }
        }
        
        // Store observation to prevent deallocation
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        task.resume()
    }
    
    private func requestUploadURL(fileName: String, fileSize: Int64, completion: @escaping (Result<UploadURLResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/upload-url") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fileName": fileName,
            "fileSize": fileSize,
            "subscriptionTier": "free" // You can make this dynamic based on user's subscription
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.encodingError))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let uploadURLResponse = try JSONDecoder().decode(UploadURLResponse.self, from: data)
                    completion(.success(uploadURLResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    private func uploadToS3(fileURL: URL, uploadURL: String, fileId: String, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard let url = URL(string: uploadURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        // Use streaming upload for large files
        let task = URLSession.shared.uploadTask(with: request, fromFile: fileURL) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                completion(.success(()))
            }
        }
        
        // Monitor upload progress
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                progressHandler(Float(progress.fractionCompleted))
            }
        }
        
        // Store observation to prevent deallocation
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        task.resume()
    }
    
    private func confirmUpload(fileId: String, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/upload-complete") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["fileId": fileId]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.encodingError))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
                    completion(.success(uploadResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - File Metadata
    func getFileMetadata(fileId: String, completion: @escaping (Result<FileMetadata, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/file/\(fileId)/metadata") else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let metadata = try JSONDecoder().decode(FileMetadata.self, from: data)
                    completion(.success(metadata))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Health Check
    func checkHealth(completion: @escaping (Result<HealthResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let healthResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
                    completion(.success(healthResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Storage Information
    func getStorageInfo(completion: @escaping (Result<StorageInfoResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/storage") else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let storageInfo = try JSONDecoder().decode(StorageInfoResponse.self, from: data)
                    completion(.success(storageInfo))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Files List
    func getFilesList(completion: @escaping (Result<[FileInfoResponse], NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/files") else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let files = try JSONDecoder().decode([FileInfoResponse].self, from: data)
                    completion(.success(files))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Delete File
    func deleteFile(fileId: String, completion: @escaping (Result<DeleteResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/file/\(fileId)") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let deleteResponse = try JSONDecoder().decode(DeleteResponse.self, from: data)
                    completion(.success(deleteResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Subscription Management
    func createSubscription(plan: String, completion: @escaping (Result<SubscriptionResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/subscription") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["plan": plan]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let subscriptionResponse = try JSONDecoder().decode(SubscriptionResponse.self, from: data)
                    completion(.success(subscriptionResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    func cancelSubscription(completion: @escaping (Result<CancelResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/subscription/cancel") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let cancelResponse = try JSONDecoder().decode(CancelResponse.self, from: data)
                    completion(.success(cancelResponse))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Authentication
    func signIn(email: String, password: String, completion: @escaping (Result<(User, String), NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/signin") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 401 {
                        completion(.failure(.serverError(401)))
                    } else {
                        completion(.failure(.serverError(httpResponse.statusCode)))
                    }
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    if let success = json?["success"] as? Bool, success {
                        if let userData = json?["user"] as? [String: Any],
                           let token = json?["token"] as? String {
                            let user = User(
                                id: userData["id"] as? String ?? UUID().uuidString,
                                email: userData["email"] as? String ?? email,
                                name: userData["name"] as? String ?? email.components(separatedBy: "@").first ?? "User",
                                subscriptionTier: User.SubscriptionTier(rawValue: userData["subscriptionTier"] as? String ?? "free") ?? .free,
                                createdAt: ISO8601DateFormatter().date(from: userData["createdAt"] as? String ?? "") ?? Date(),
                                lastSignIn: ISO8601DateFormatter().date(from: userData["lastLogin"] as? String ?? "") ?? Date(),
                                profilePictureData: nil,
                                nextBillingDate: nil
                            )
                            completion(.success((user, token)))
                        } else {
                            completion(.failure(.invalidResponse))
                        }
                    } else {
                        let errorMessage = json?["error"] as? String ?? "Unknown error"
                        completion(.failure(.serverError(400)))
                    }
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    func signUp(email: String, password: String, name: String, phone: String?, completion: @escaping (Result<User, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/signup") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "email": email,
            "password": password,
            "name": name
        ]
        
        if let phone = phone, !phone.isEmpty {
            body["phone"] = phone
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    if let success = json?["success"] as? Bool, success {
                        if let userData = json?["user"] as? [String: Any] {
                            let user = User(
                                id: userData["id"] as? String ?? UUID().uuidString,
                                email: userData["email"] as? String ?? email,
                                name: userData["name"] as? String ?? name,
                                subscriptionTier: User.SubscriptionTier(rawValue: userData["subscriptionTier"] as? String ?? "free") ?? .free,
                                createdAt: ISO8601DateFormatter().date(from: userData["createdAt"] as? String ?? "") ?? Date(),
                                lastSignIn: ISO8601DateFormatter().date(from: userData["lastLogin"] as? String ?? "") ?? Date(),
                                profilePictureData: nil,
                                nextBillingDate: nil
                            )
                            completion(.success(user))
                        } else {
                            completion(.failure(.invalidResponse))
                        }
                    } else {
                        let errorMessage = json?["error"] as? String ?? "Unknown error"
                        completion(.failure(.serverError(400)))
                    }
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    func updateEmail(currentEmail: String, newEmail: String, completion: @escaping (Result<User, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/update-email") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "currentEmail": currentEmail,
            "newEmail": newEmail
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    if let success = json?["success"] as? Bool, success {
                        if let userData = json?["user"] as? [String: Any] {
                            let user = User(
                                id: userData["id"] as? String ?? UUID().uuidString,
                                email: userData["email"] as? String ?? newEmail,
                                name: userData["name"] as? String ?? "",
                                subscriptionTier: User.SubscriptionTier(rawValue: userData["subscriptionTier"] as? String ?? "free") ?? .free,
                                createdAt: ISO8601DateFormatter().date(from: userData["createdAt"] as? String ?? "") ?? Date(),
                                lastSignIn: ISO8601DateFormatter().date(from: userData["lastLogin"] as? String ?? "") ?? Date(),
                                profilePictureData: nil,
                                nextBillingDate: nil
                            )
                            completion(.success(user))
                        } else {
                            completion(.failure(.invalidResponse))
                        }
                    } else {
                        let errorMessage = json?["error"] as? String ?? "Unknown error"
                        completion(.failure(.serverError(400)))
                    }
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    func updatePassword(email: String, currentPassword: String, newPassword: String, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/update-password") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "email": email,
            "currentPassword": currentPassword,
            "newPassword": newPassword
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                completion(.success(()))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Subscription Management
    func updateSubscription(tier: User.SubscriptionTier, completion: @escaping (Result<User, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/update-subscription") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if user is logged in
        if let token = UserManager.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = [
            "subscriptionTier": tier.rawValue
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    if let success = json?["success"] as? Bool, success {
                        if let userData = json?["user"] as? [String: Any] {
                            let user = User(
                                id: userData["id"] as? String ?? UUID().uuidString,
                                email: userData["email"] as? String ?? "",
                                name: userData["name"] as? String ?? "",
                                subscriptionTier: User.SubscriptionTier(rawValue: userData["subscriptionTier"] as? String ?? "free") ?? .free,
                                createdAt: ISO8601DateFormatter().date(from: userData["createdAt"] as? String ?? "") ?? Date(),
                                lastSignIn: ISO8601DateFormatter().date(from: userData["lastSignIn"] as? String ?? "") ?? Date(),
                                profilePictureData: nil,
                                nextBillingDate: nil
                            )
                            completion(.success(user))
                        } else {
                            completion(.failure(.invalidResponse))
                        }
                    } else {
                        let errorMessage = json?["error"] as? String ?? "Unknown error"
                        completion(.failure(.serverError(400)))
                    }
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    func syncUserData(completion: @escaping (Result<User, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/sync") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if user is logged in
        if let token = UserManager.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    if let success = json?["success"] as? Bool, success {
                        if let userData = json?["user"] as? [String: Any] {
                            let user = User(
                                id: userData["id"] as? String ?? UUID().uuidString,
                                email: userData["email"] as? String ?? "",
                                name: userData["name"] as? String ?? "",
                                subscriptionTier: User.SubscriptionTier(rawValue: userData["subscriptionTier"] as? String ?? "free") ?? .free,
                                createdAt: ISO8601DateFormatter().date(from: userData["createdAt"] as? String ?? "") ?? Date(),
                                lastSignIn: ISO8601DateFormatter().date(from: userData["lastSignIn"] as? String ?? "") ?? Date(),
                                profilePictureData: nil,
                                nextBillingDate: nil
                            )
                            completion(.success(user))
                        } else {
                            completion(.failure(.invalidResponse))
                        }
                    } else {
                        let errorMessage = json?["error"] as? String ?? "Unknown error"
                        completion(.failure(.serverError(400)))
                    }
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
}

// MARK: - Response Models
struct UploadResponse: Codable {
    let success: Bool
    let fileId: String
    let downloadLink: String
    let fileName: String
    let fileSize: Int
    let expiresAt: String
}

struct FileMetadata: Codable {
    let id: String
    let originalName: String
    let size: Int
    let mimeType: String
    let uploadDate: String
    let expiresAt: String
    let downloadCount: Int
    let isActive: Bool
}

struct HealthResponse: Codable {
    let status: String
    let timestamp: String
}

struct StorageInfoResponse: Codable {
    let totalFiles: Int
    let totalSizeBytes: Int64
    let totalSizeMB: String
    let totalSizeGB: String
    let lastUpdated: String
    
    // Computed properties for backward compatibility
    var usedStorage: Int64 {
        return totalSizeBytes
    }
    
    var totalStorage: Int64 {
        // Default to 100MB for free tier, can be overridden
        return 100 * 1024 * 1024
    }
    
    var activeFiles: Int {
        return totalFiles // Assuming all files are active for now
    }
    
    var expiredFiles: Int {
        return 0 // We'll need to calculate this separately if needed
    }
}

struct FileInfoResponse: Codable {
    let id: String
    let fileName: String
    let fileSize: Int64
    let uploadDate: String
    let expiryDate: String
    let isExpired: Bool
}

struct DeleteResponse: Codable {
    let success: Bool
    let message: String
}

struct SubscriptionResponse: Codable {
    let success: Bool
    let subscriptionId: String
    let plan: String
    let status: String
    let nextBillingDate: String
}

struct CancelResponse: Codable {
    let success: Bool
    let message: String
    let cancelledAt: String
}

struct UploadURLResponse: Codable {
    let uploadUrl: String
    let fileId: String
}

struct S3UploadURLResponse: Codable {
    let url: String
    let fileId: String
    let s3Key: String
}

struct S3DownloadURLResponse: Codable {
    let url: String
}

// MARK: - Error Types
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(Int)
    case noData
    case decodingError(Error)
    case fileReadError
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error with status code: \(code)"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .fileReadError:
            return "Failed to read file"
        case .encodingError:
            return "Failed to encode request body"
        }
    }
} 