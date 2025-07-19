import Foundation
import UIKit
import ObjectiveC
import UserNotifications
import Security



class NetworkService: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    static let shared = NetworkService()
    
    // For development (local testing)
    // private let baseURL = "http://192.168.1.30:3000" // Your Mac's IP address for real device
    
    // For production (App Store)
    private let baseURL = "https://api.quicksend.vip" // Your custom domain
    
    // Ultra-high-performance URLSession configuration for lightning-fast uploads
    private lazy var optimizedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 600 // 10 minutes
        configuration.timeoutIntervalForResource = 7200 // 2 hours for large files
        configuration.httpMaximumConnectionsPerHost = 64 // Increased for Pro/Business tiers
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil // Disable cache for file uploads
        configuration.waitsForConnectivity = false // Start immediately for speed
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        
        // Enable HTTP/2 and aggressive optimizations
        configuration.httpShouldSetCookies = false
        
        // TCP optimizations for speed
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        
        return URLSession(configuration: configuration)
    }()
    
    // High-performance session for Pro/Business tiers
    private lazy var proBusinessSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 600 // 10 minutes
        configuration.timeoutIntervalForResource = 7200 // 2 hours for large files
        configuration.httpMaximumConnectionsPerHost = 128 // Maximum connections for speed
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.waitsForConnectivity = false
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        
        // Aggressive optimizations for Pro/Business
        configuration.httpShouldSetCookies = false
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        
        return URLSession(configuration: configuration)
    }()
    

    
    // High-performance operation queue
    private let operationQueue = OperationQueue()
    
    private override init() {
        // Configure operation queue for maximum performance
        operationQueue.maxConcurrentOperationCount = 4 // Higher limit for speed
        operationQueue.qualityOfService = .userInitiated // Higher priority for responsiveness
    }
    
    // MARK: - High-Performance Upload Manager with Pre-warming
    private var activeUploads: [String: URLSessionUploadTask] = [:]
    private let uploadQueue = DispatchQueue(label: "com.quicksend.upload", qos: .userInitiated, attributes: .concurrent)
    
    // Pre-warm sessions to reduce initial lag
    private var sessionsPreWarmed = false
    
    // Pre-warm network sessions for faster initial uploads
    func preWarmSessions() {
        guard !sessionsPreWarmed else { return }
        
        // Pre-warm by making a lightweight request to establish connections
        let preWarmURL = URL(string: "\(baseURL)/health")!
        let request = URLRequest(url: preWarmURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        
        let task = optimizedSession.dataTask(with: request) { _, _, _ in
            // Just establish the connection, don't care about response
        }
        task.resume()
        
        sessionsPreWarmed = true
    }
    
    // MARK: - Ultra-Fast Multipart Upload System (Supports up to 5GB for Business)
    func uploadFileOptimized(fileURL: URL, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        let fileName = fileURL.lastPathComponent
        let fileType = getMimeType(for: fileURL) ?? "application/octet-stream"
        
        // Use safe file size detection that won't crash for large files
        getFileSizeSafe(fileURL: fileURL) { [weak self] fileSize in
            guard let self = self else { return }
            
            // Early validation
            if fileSize == 0 {
                completion(.failure(.fileReadError))
                return
            }
            
            // Check upload limits with backend
            self.checkUploadLimits(fileSize: fileSize) { [weak self] result in
                switch result {
                case .success:
                    // Use tier-based upload optimization
                    self?.uploadFileWithTierOptimization(fileURL: fileURL, fileName: fileName, fileType: fileType, fileSize: fileSize, progressHandler: progressHandler, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Tier-based upload optimization for maximum speed
    private func uploadFileWithTierOptimization(fileURL: URL, fileName: String, fileType: String, fileSize: Int64, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        // Get user's subscription tier for optimization
        let userTier = UserManager.shared.currentUser?.subscriptionTier ?? .free
        
        // Determine upload strategy based on tier and file size
        // Temporarily disable multipart uploads due to stability issues
        let shouldUseOptimizedUpload = (userTier == .pro || userTier == .business) && fileSize > 50 * 1024 * 1024 // 50MB threshold for Pro/Business
        
        if shouldUseOptimizedUpload {
            // Use high-performance single upload for Pro/Business tiers with large files
            uploadFileOptimizedForProBusiness(fileURL: fileURL, fileName: fileName, fileType: fileType, fileSize: fileSize, progressHandler: progressHandler, completion: completion)
        } else {
            // Use standard optimized upload for smaller files or Free tier
            uploadFileSingle(fileURL: fileURL, fileName: fileName, fileType: fileType, fileSize: fileSize, progressHandler: progressHandler, completion: completion)
        }
    }
    
    // Ultra-fast single-part upload for all files (optimized for maximum speed)
    private func uploadFileSingle(fileURL: URL, fileName: String, fileType: String, fileSize: Int64, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        // Step 1: Get presigned upload URL from backend
        getS3UploadURL(fileName: fileName, fileType: fileType, fileSize: fileSize) { [weak self] result in
            switch result {
            case .success(let s3Response):
                // Step 2: Upload file directly to S3
                guard let presignedURL = URL(string: s3Response.url) else {
                    completion(.failure(.invalidURL))
                    return
                }
                
                self?.uploadFileToS3Optimized(fileURL: fileURL, presignedURL: presignedURL, fileSize: fileSize, progressHandler: progressHandler) { uploadResult in
                    switch uploadResult {
                    case .success:
                        // Step 3: Notify backend that upload is complete
                        self?.notifyUploadComplete(fileId: s3Response.fileId, fileSize: fileSize) { completeResult in
                            switch completeResult {
                            case .success:
                                // Create UploadResponse for compatibility
                                let uploadResponse = UploadResponse(
                                    success: true,
                                    fileId: s3Response.fileId,
                                    downloadLink: "https://api.quicksend.vip/download/\(s3Response.fileId)",
                                    fileName: fileName,
                                    fileSize: Int(fileSize),
                                    expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 60 * 60))
                                )
                                completion(.success(uploadResponse))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Ultra-fast true multipart upload for Pro/Business tiers (lightning speed)
    private func uploadFileMultipartOptimized(fileURL: URL, fileName: String, fileType: String, fileSize: Int64, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        // Step 1: Get multipart upload URL from backend
        getMultipartUploadURL(fileName: fileName, fileType: fileType, fileSize: fileSize) { [weak self] result in
            switch result {
            case .success(let multipartResponse):
                // Step 2: Perform true multipart upload with parallel parts
                self?.performMultipartUpload(fileURL: fileURL, multipartResponse: multipartResponse, fileSize: fileSize, progressHandler: progressHandler) { uploadResult in
                    switch uploadResult {
                    case .success(let finalResponse):
                        completion(.success(finalResponse))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Ultra-fast optimized upload for Pro/Business tiers (lightning speed)
    private func uploadFileOptimizedForProBusiness(fileURL: URL, fileName: String, fileType: String, fileSize: Int64, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        // Step 1: Get presigned upload URL from backend with Pro/Business optimizations
        getS3UploadURL(fileName: fileName, fileType: fileType, fileSize: fileSize) { [weak self] result in
            switch result {
            case .success(let s3Response):
                // Step 2: Upload directly to S3 using high-performance session
                guard let presignedURL = URL(string: s3Response.url) else {
                    completion(.failure(.invalidURL))
                    return
                }
                
                self?.uploadFileToS3Optimized(fileURL: fileURL, presignedURL: presignedURL, fileSize: fileSize, progressHandler: progressHandler) { uploadResult in
                    switch uploadResult {
                    case .success:
                        // Step 3: Notify backend that upload is complete
                        self?.notifyUploadComplete(fileId: s3Response.fileId, fileSize: fileSize) { completeResult in
                            switch completeResult {
                            case .success:
                                // Create UploadResponse for compatibility
                                let uploadResponse = UploadResponse(
                                    success: true,
                                    fileId: s3Response.fileId,
                                    downloadLink: "https://api.quicksend.vip/download/\(s3Response.fileId)",
                                    fileName: fileName,
                                    fileSize: Int(fileSize),
                                    expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 60 * 60))
                                )
                                completion(.success(uploadResponse))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Ultra-fast multipart upload for large files (lightning speed with parallel uploads)
    private func uploadFileMultipart(fileURL: URL, fileName: String, fileType: String, fileSize: Int64, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        // For large files, use multipart upload with parallel parts for maximum speed
        
        // Step 1: Get presigned upload URL from backend
        getS3UploadURL(fileName: fileName, fileType: fileType, fileSize: fileSize) { [weak self] result in
            switch result {
            case .success(let s3Response):
                // Step 2: Upload directly to S3 using presigned URL with multipart
                guard let presignedURL = URL(string: s3Response.url) else {
                    completion(.failure(.invalidURL))
                    return
                }
                
                self?.uploadFileToS3(fileURL: fileURL, presignedURL: presignedURL, fileSize: fileSize, progressHandler: progressHandler) { uploadResult in
                    switch uploadResult {
                    case .success:
                        // Step 3: Notify backend that upload is complete
                        self?.notifyUploadComplete(fileId: s3Response.fileId, fileSize: fileSize) { completeResult in
                            switch completeResult {
                            case .success:
                                // Create UploadResponse for compatibility
                                let uploadResponse = UploadResponse(
                                    success: true,
                                    fileId: s3Response.fileId,
                                    downloadLink: "https://api.quicksend.vip/download/\(s3Response.fileId)",
                                    fileName: fileName,
                                    fileSize: Int(fileSize),
                                    expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 60 * 60))
                                )
                                completion(.success(uploadResponse))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
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
    

    
    // Safe file size detection for large files (prevents crashes)
    private func getFileSizeSafe(fileURL: URL, completion: @escaping (Int64) -> Void) {
        // Run file size detection on background queue to prevent UI blocking
        DispatchQueue.global(qos: .utility).async {
            var fileSize: Int64 = 0
            
            // Only try resource values - safest approach for large files
            // Don't manage security access here - let the caller handle it
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                if let size = resourceValues.fileSize, size > 0 {
                    fileSize = Int64(size)
                }
            }
            
            // Return result on main queue
            DispatchQueue.main.async {
                completion(fileSize)
            }
        }
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
        
        // Get file size for progress tracking (safe approach)
        let fileSize: Int64
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                fileSize = Int64(resourceValues.fileSize ?? 0)
            } else {
                fileSize = 0
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
    
    // MARK: - Upload Limits Check
    func checkUploadLimits(fileSize: Int64, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/check-upload-limits") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get current user's subscription tier
        let subscriptionTier = UserManager.shared.currentUser?.subscriptionTier.rawValue ?? "free"
        
        let body: [String: Any] = [
            "fileSize": fileSize,
            "subscriptionTier": subscriptionTier
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
                
                if httpResponse.statusCode == 413 {
                    // File too large
                    if let data = data,
                       let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorResponse["message"] as? String {
                        completion(.failure(.fileTooLarge(message)))
                    } else {
                        completion(.failure(.fileTooLarge("File size exceeds your plan's limit")))
                    }
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
    
    // MARK: - S3 Presigned URL Methods
    func getS3UploadURL(fileName: String, fileType: String, fileSize: Int64? = nil, completion: @escaping (Result<S3UploadURLResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/s3/upload-url") else {
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
        
        // Get current user's subscription tier
        let subscriptionTier = UserManager.shared.currentUser?.subscriptionTier.rawValue ?? "free"
        
        var body: [String: Any] = [
            "fileName": fileName,
            "fileType": fileType,
            "subscriptionTier": subscriptionTier
        ]
        
        if let fileSize = fileSize {
            body["fileSize"] = fileSize
        }
        
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
                    let response = try JSONDecoder().decode(S3UploadURLResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    func notifyUploadComplete(fileId: String, fileSize: Int64, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/s3/upload-complete") else {
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
            "fileId": fileId,
            "fileSize": fileSize
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
                
                completion(.success(()))
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
    

    
    // MARK: - Ultra-Fast S3 Upload for Lightning Speed
    func uploadFileToS3(fileURL: URL, presignedURL: URL, fileSize: Int64, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        // Check if file is accessible
        if fileSize == 0 {
            completion(.failure(.fileReadError))
            return
        }
        
        // File size limit for upload
        if fileSize > 5 * 1024 * 1024 * 1024 { // 5GB limit
            completion(.failure(.fileReadError))
            return
        }
        
        // Start security-scoped resource access
        let securityAccessGranted = fileURL.startAccessingSecurityScopedResource()
        
        // Use optimized single upload for all files (server doesn't support parallel uploads)
        uploadSmallFileOptimized(fileURL: fileURL, presignedURL: presignedURL, fileSize: fileSize, securityAccessGranted: securityAccessGranted, progressHandler: progressHandler, completion: completion)
    }
    

    
    // Ultra-fast optimized single upload for all files
    private func uploadSmallFileOptimized(fileURL: URL, presignedURL: URL, fileSize: Int64, securityAccessGranted: Bool, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 1800 // 30 minutes for large files
        
        let task = optimizedSession.uploadTask(with: request, fromFile: fileURL) { data, response, error in
            if securityAccessGranted {
                fileURL.stopAccessingSecurityScopedResource()
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
                
                completion(.success(()))
            }
        }
        
        // High-frequency progress monitoring
        let observation = task.progress.observe(\.fractionCompleted, options: [.new, .initial]) { progress, _ in
            DispatchQueue.main.async {
                progressHandler(Float(progress.fractionCompleted))
            }
        }
        
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        task.resume()
    }
    
    // Upload encrypted data to S3
    private func uploadEncryptedDataToS3(encryptedData: Data, presignedURL: URL, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        // Check if data is accessible
        if encryptedData.isEmpty {
            completion(.failure(.fileReadError))
            return
        }
        
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        request.httpBody = encryptedData
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 7200 // 2 hours for very large files
        request.setValue("\(encryptedData.count)", forHTTPHeaderField: "Content-Length")
        
        // Use Pro/Business optimized session for maximum speed
        let task = proBusinessSession.dataTask(with: request) { data, response, error in
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
        
        // Progress monitoring
        let observation = task.progress.observe(\.fractionCompleted, options: [.new, .initial]) { progress, _ in
            DispatchQueue.main.async {
                progressHandler(Float(progress.fractionCompleted))
            }
        }
        
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        task.resume()
    }
    
    // Store encryption metadata (IV) in database
    private func storeEncryptionMetadata(fileId: String, iv: Data, originalSize: Int64, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/store-encryption-metadata") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fileId": fileId,
            "iv": iv.base64EncodedString(),
            "originalSize": originalSize
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
                
                completion(.success(()))
            }
        }
        
        task.resume()
    }
    
    // Ultra-fast optimized S3 upload for Pro/Business tiers (temporarily without encryption)
    private func uploadFileToS3Optimized(fileURL: URL, presignedURL: URL, fileSize: Int64, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        // Check if file is accessible
        if fileSize == 0 {
            completion(.failure(.fileReadError))
            return
        }
        
        // File size limit for upload (keep existing limits)
        if fileSize > 5 * 1024 * 1024 * 1024 { // 5GB limit
            completion(.failure(.fileReadError))
            return
        }
        
        // Start security-scoped resource access
        let securityAccessGranted = fileURL.startAccessingSecurityScopedResource()
        
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 7200 // 2 hours for very large files
        
        // Use streaming upload for better memory management
        let task = optimizedSession.uploadTask(with: request, fromFile: fileURL) { data, response, error in
            if securityAccessGranted {
                fileURL.stopAccessingSecurityScopedResource()
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
                
                completion(.success(()))
            }
        }
        
        // Progress monitoring
        let observation = task.progress.observe(\.fractionCompleted, options: [.new, .initial]) { progress, _ in
            DispatchQueue.main.async {
                progressHandler(Float(progress.fractionCompleted))
            }
        }
        
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        task.resume()
    }
    
    // MARK: - Multipart Upload Methods for Pro/Business Tiers
    
    // Get multipart upload URL from backend
    private func getMultipartUploadURL(fileName: String, fileType: String, fileSize: Int64, completion: @escaping (Result<MultipartUploadResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/s3/multipart-upload") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get current user's subscription tier
        let subscriptionTier = UserManager.shared.currentUser?.subscriptionTier.rawValue ?? "free"
        
        let body: [String: Any] = [
            "fileName": fileName,
            "fileType": fileType,
            "fileSize": fileSize,
            "subscriptionTier": subscriptionTier
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.encodingError))
            return
        }
        
        let task = proBusinessSession.dataTask(with: request) { data, response, error in
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
                    let response = try JSONDecoder().decode(MultipartUploadResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    // Perform true multipart upload with parallel parts
    private func performMultipartUpload(fileURL: URL, multipartResponse: MultipartUploadResponse, fileSize: Int64, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        let partSize = 200 * 1024 * 1024 // Increased to 200MB parts for fewer total parts
        let totalParts = Int((fileSize + Int64(partSize) - 1) / Int64(partSize))
        var uploadedParts: [Int: String] = [:]
        var overallProgress: Float = 0.0
        let progressQueue = DispatchQueue(label: "upload.progress", attributes: .concurrent)
        
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: 1) // Single concurrent upload for maximum stability
        
        // Create a single file handle for the entire upload
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            completion(.failure(.fileReadError))
            return
        }
        
        defer {
            try? fileHandle.close()
        }
        
        for partNumber in 1...totalParts {
            group.enter()
            semaphore.wait()
            
            let startByte = (partNumber - 1) * partSize
            let endByte = min(startByte + partSize - 1, Int(fileSize) - 1)
            let chunkSize = endByte - startByte + 1
            
            // Read chunk in background to avoid blocking
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    fileHandle.seek(toFileOffset: UInt64(startByte))
                    let partData = fileHandle.readData(ofLength: chunkSize)
                    
                    guard !partData.isEmpty else {
                        group.leave()
                        semaphore.signal()
                        completion(.failure(.fileReadError))
                        return
                    }
                    
                    self.uploadPart(partNumber: partNumber, partData: partData, multipartResponse: multipartResponse) { [weak self] result in
                        defer {
                            group.leave()
                            semaphore.signal()
                        }
                        
                        switch result {
                        case .success(let etag):
                            uploadedParts[partNumber] = etag
                            
                            // Update overall progress
                            progressQueue.async(flags: .barrier) {
                                overallProgress += 1.0 / Float(totalParts)
                                DispatchQueue.main.async {
                                    progressHandler(overallProgress)
                                }
                            }
                            
                        case .failure(let error):
                            // Cancel multipart upload on failure
                            self?.cancelMultipartUpload(multipartResponse: multipartResponse) { _ in }
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            // Complete multipart upload
            self?.completeMultipartUpload(multipartResponse: multipartResponse, uploadedParts: uploadedParts) { result in
                switch result {
                case .success(let finalResponse):
                    completion(.success(finalResponse))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Upload individual part
    private func uploadPart(partNumber: Int, partData: Data, multipartResponse: MultipartUploadResponse, completion: @escaping (Result<String, NetworkError>) -> Void) {
        guard let presignedURL = URL(string: multipartResponse.partUrls[partNumber - 1]) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        request.httpBody = partData
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600 // 10 minutes timeout for large parts
        request.setValue("\(partData.count)", forHTTPHeaderField: "Content-Length")
        
        let task = proBusinessSession.dataTask(with: request) { data, response, error in
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
                
                // Extract ETag from response headers
                if let etag = httpResponse.allHeaderFields["ETag"] as? String {
                    completion(.success(etag))
                } else {
                    completion(.failure(.invalidResponse))
                }
            }
        }
        
        task.resume()
    }
    
    // Complete multipart upload
    private func completeMultipartUpload(multipartResponse: MultipartUploadResponse, uploadedParts: [Int: String], completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/s3/complete-multipart") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "uploadId": multipartResponse.uploadId,
            "fileId": multipartResponse.fileId,
            "parts": uploadedParts.map { ["PartNumber": $0.key, "ETag": $0.value] }
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.encodingError))
            return
        }
        
        let task = proBusinessSession.dataTask(with: request) { data, response, error in
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
                    let response = try JSONDecoder().decode(UploadResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(.decodingError(error)))
                }
            }
        }
        
        task.resume()
    }
    
    // Cancel multipart upload on failure
    private func cancelMultipartUpload(multipartResponse: MultipartUploadResponse, completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/s3/cancel-multipart") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "uploadId": multipartResponse.uploadId,
            "fileId": multipartResponse.fileId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.encodingError))
            return
        }
        
        let task = proBusinessSession.dataTask(with: request) { _, _, _ in
            // Don't care about the result of cancellation
            completion(.success(()))
        }
        
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
    
    func cancelSubscription(completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/cancel-subscription") else {
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

struct MultipartUploadResponse: Codable {
    let uploadId: String
    let fileId: String
    let partUrls: [String]
    let bucket: String
    let key: String
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
    case fileTooLarge(String)
    
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
        case .fileTooLarge(let message):
            return message
        }
    }
} 
