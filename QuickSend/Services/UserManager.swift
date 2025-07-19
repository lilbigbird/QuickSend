import Foundation
import UIKit

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
    
    // MARK: - Subscription Management
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
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: NSNotification.Name("SubscriptionTierChanged"), object: nil)
        
        // Sync with backend
        NetworkService.shared.updateSubscription(tier: tier) { result in
            switch result {
            case .success(let syncedUser):
                // Update with the synced user data from backend
                self.currentUser = syncedUser
                // Post notification again after backend sync
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("SubscriptionTierChanged"), object: nil)
                }
            case .failure(let error):
                print("Failed to sync subscription with backend: \(error)")
                // Keep the local update even if backend sync fails
            }
        }
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