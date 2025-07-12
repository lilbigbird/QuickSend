import Foundation
import UIKit

class NetworkService {
    static let shared = NetworkService()
    
    // For development (local testing)
    // private let baseURL = "http://192.168.1.30:3000" // Your Mac's IP address for real device
    
    // For production (App Store)
    private let baseURL = "https://api.quicksend.vip" // Your custom domain
    
    private init() {}
    
    // MARK: - File Upload
    func uploadFile(fileURL: URL, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<UploadResponse, NetworkError>) -> Void) {
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
        // Try to access the security-scoped resource first
        if fileURL.startAccessingSecurityScopedResource() {
            defer { fileURL.stopAccessingSecurityScopedResource() }
            
            // Try multiple approaches to get file size
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
        
        // Create multipart body with streaming for large files
        let body = createMultipartBody(fileURL: fileURL, boundary: boundary, progressHandler: progressHandler)
        request.httpBody = body
        
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
    
    private func createMultipartBody(fileURL: URL, boundary: String, progressHandler: @escaping (Float) -> Void) -> Data {
        var body = Data()
        
        // Add file header
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        
        // Add file data in chunks to avoid memory issues
        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            defer { fileHandle.closeFile() }
            
            let chunkSize = 64 * 1024 // 64KB chunks
            var totalBytesRead: Int64 = 0
            
            // Get file size using the same method as above
            let fileSize: Int64
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                fileSize = Int64(resourceValues.fileSize ?? 0)
            } else if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
                fileSize = attributes[.size] as? Int64 ?? 0
            } else {
                fileSize = 0
            }
            
            while true {
                let data = fileHandle.readData(ofLength: chunkSize)
                if data.isEmpty { break }
                
                body.append(data)
                totalBytesRead += Int64(data.count)
                
                // Update progress
                let progress = Float(totalBytesRead) / Float(fileSize)
                DispatchQueue.main.async {
                    progressHandler(progress)
                }
            }
        } catch {
            print("Error reading file: \(error)")
        }
        
        // Add closing boundary
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
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
    func signIn(email: String, password: String, completion: @escaping (Result<User, NetworkError>) -> Void) {
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
                        if let userData = json?["user"] as? [String: Any] {
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
                            completion(.success(user))
                        } else {
                            completion(.failure(.invalidResponse))
                        }
                    } else {
                        _ = json?["error"] as? String ?? "Unknown error"
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
    let usedStorage: Int64
    let totalStorage: Int64
    let totalFiles: Int
    let activeFiles: Int
    let expiredFiles: Int
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

// MARK: - Error Types
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(Int)
    case noData
    case decodingError(Error)
    case fileReadError
    
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
        }
    }
} 