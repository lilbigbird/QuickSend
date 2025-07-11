import Foundation

class UserManager {
    static let shared = UserManager()
    
    private let userDefaults = UserDefaults.standard
    private let currentUserKey = "currentUser"
    private let isSignedInKey = "isSignedIn"
    
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
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        NetworkService.shared.signIn(email: email, password: password) { result in
            switch result {
            case .success(let user):
                self.currentUser = user
                completion(.success(user))
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
    }
    
    func updateSubscriptionTier(_ tier: User.SubscriptionTier) {
        guard let user = currentUser else { return }
        
        // Calculate next billing date (one month from now for paid tiers)
        let nextBillingDate: Date?
        if tier == .free {
            nextBillingDate = nil
        } else {
            let calendar = Calendar.current
            nextBillingDate = calendar.date(byAdding: .month, value: 1, to: Date())
        }
        
        // Create updated user with new subscription tier
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
} 