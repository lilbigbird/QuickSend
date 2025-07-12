import Foundation

class UserManager {
    static let shared = UserManager()
    
    private let userDefaults = UserDefaults.standard
    private let currentUserKey = "currentUser"
    private let isSignedInKey = "isSignedIn"
    private let authTokenKey = "authToken"
    
    private init() {}
    
    // MARK: - Current User
    var currentUser: User? {
        get {
            guard let data = userDefaults.data(forKey: currentUserKey),
                  let user = try? JSONDecoder().decode(User.self, from: data) else {
                return nil
            }
            return user
        }
        set {
            if let user = newValue,
               let data = try? JSONEncoder().encode(user) {
                userDefaults.set(data, forKey: currentUserKey)
                userDefaults.set(true, forKey: isSignedInKey)
            } else {
                userDefaults.removeObject(forKey: currentUserKey)
                userDefaults.set(false, forKey: isSignedInKey)
            }
        }
    }
    
    var isSignedIn: Bool {
        return userDefaults.bool(forKey: isSignedInKey) && currentUser != nil
    }
    
    var authToken: String? {
        get {
            return userDefaults.string(forKey: authTokenKey)
        }
        set {
            if let token = newValue {
                userDefaults.set(token, forKey: authTokenKey)
            } else {
                userDefaults.removeObject(forKey: authTokenKey)
            }
        }
    }
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        NetworkService.shared.signIn(email: email, password: password) { result in
            switch result {
            case .success(let (user, token)):
                self.currentUser = user
                self.authToken = token
                
                // Sync subscription data from backend
                NetworkService.shared.syncUserData { syncResult in
                    switch syncResult {
                    case .success(let syncedUser):
                        // Update local user with synced subscription data
                        self.currentUser = syncedUser
                        completion(.success(syncedUser))
                    case .failure(_):
                        // If sync fails, still complete with the original user data
                        completion(.success(user))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func signUp(email: String, password: String, name: String, completion: @escaping (Result<User, Error>) -> Void) {
        NetworkService.shared.signUp(email: email, password: password, name: name, phone: nil) { result in
            switch result {
            case .success(let user):
                self.currentUser = user
                completion(.success(user))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func createAccount(email: String, password: String, phone: String?, completion: @escaping (Result<User, Error>) -> Void) {
        NetworkService.shared.signUp(email: email, password: password, name: email.components(separatedBy: "@").first ?? "User", phone: phone) { result in
            switch result {
            case .success(let user):
                self.currentUser = user
                completion(.success(user))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func signOut() {
        currentUser = nil
        authToken = nil
    }
    
    func updateSubscriptionTier(_ tier: User.SubscriptionTier) {
        guard let user = currentUser else { return }
        
        // Update local user immediately for responsive UI
        let nextBillingDate: Date?
        if tier == .free {
            nextBillingDate = nil
        } else {
            let calendar = Calendar.current
            nextBillingDate = calendar.date(byAdding: .month, value: 1, to: Date())
        }
        
        let updatedUser = User(
            id: user.id,
            email: user.email,
            name: user.name,
            subscriptionTier: tier,
            createdAt: user.createdAt,
            lastSignIn: user.lastSignIn,
            profilePictureData: user.profilePictureData,
            nextBillingDate: nextBillingDate
        )
        
        currentUser = updatedUser
        
        // Sync with backend
        NetworkService.shared.updateSubscription(tier: tier) { result in
            switch result {
            case .success(let syncedUser):
                // Update with the synced user data from backend
                self.currentUser = syncedUser
            case .failure(let error):
                print("Failed to sync subscription with backend: \(error)")
                // Keep the local update even if backend sync fails
            }
        }
    }
    
    func updateUserName(_ name: String) {
        guard let user = currentUser else { return }
        
        // Create updated user with new name
        let updatedUser = User(
            id: user.id,
            email: user.email,
            name: name,
            subscriptionTier: user.subscriptionTier,
            createdAt: user.createdAt,
            lastSignIn: user.lastSignIn,
            profilePictureData: user.profilePictureData,
            nextBillingDate: user.nextBillingDate
        )
        
        currentUser = updatedUser
    }
    
    func updateProfilePicture(_ imageData: Data?) {
        guard let user = currentUser else { return }
        
        // Create updated user with new profile picture
        let updatedUser = User(
            id: user.id,
            email: user.email,
            name: user.name,
            subscriptionTier: user.subscriptionTier,
            createdAt: user.createdAt,
            lastSignIn: user.lastSignIn,
            profilePictureData: imageData,
            nextBillingDate: user.nextBillingDate
        )
        
        currentUser = updatedUser
    }
    
    // MARK: - Guest Mode
    func createGuestUser() -> User {
        let guestUser = User(
            id: "guest_\(UUID().uuidString)",
            email: "guest@quicksend.app",
            name: "Guest User",
            subscriptionTier: .free,
            createdAt: Date(),
            lastSignIn: Date(),
            profilePictureData: nil,
            nextBillingDate: nil
        )
        
        currentUser = guestUser
        return guestUser
    }
    
    // MARK: - Validation
    func canUploadFile(size: Int64) -> Bool {
        guard let user = currentUser else { return false }
        return size <= user.subscriptionTier.maxFileSize
    }
    
    func getMaxFileSize() -> Int64 {
        return currentUser?.subscriptionTier.maxFileSize ?? User.SubscriptionTier.free.maxFileSize
    }
    
    func getMaxExpiryDays() -> Int {
        return currentUser?.subscriptionTier.maxExpiryDays ?? User.SubscriptionTier.free.maxExpiryDays
    }
    
    // MARK: - Data Synchronization
    func syncUserDataFromBackend(completion: @escaping (Bool) -> Void = { _ in }) {
        // Only sync if user is signed in
        guard isSignedIn, let _ = authToken else {
            completion(false)
            return
        }
        
        NetworkService.shared.syncUserData { result in
            switch result {
            case .success(let syncedUser):
                // Update local user with synced data from backend
                self.currentUser = syncedUser
                print("✅ User data synced successfully from backend")
                completion(true)
            case .failure(let error):
                print("❌ Failed to sync user data: \(error)")
                completion(false)
            }
        }
    }
} 