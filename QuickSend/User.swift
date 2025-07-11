import Foundation

struct User: Codable {
    let id: String
    let email: String
    let name: String
    let subscriptionTier: SubscriptionTier
    let createdAt: Date
    let lastSignIn: Date
    let profilePictureData: Data?
    let nextBillingDate: Date?
    
    enum SubscriptionTier: String, Codable, CaseIterable {
        case free = "free"
        case pro = "pro"
        case business = "business"
        
        var displayName: String {
            switch self {
            case .free: return "Free"
            case .pro: return "Pro"
            case .business: return "Business"
            }
        }
        
        var maxFileSize: Int64 {
            switch self {
            case .free: return 100 * 1024 * 1024 // 100MB
            case .pro: return 1024 * 1024 * 1024 // 1GB
            case .business: return 5 * 1024 * 1024 * 1024 // 5GB
            }
        }
        
        var maxExpiryDays: Int {
            switch self {
            case .free: return 7
            case .pro: return 30
            case .business: return 90
            }
        }
        
        var maxUploadsPerMonth: Int {
            switch self {
            case .free: return 10
            case .pro: return 100
            case .business: return 1000
            }
        }
        
        var priceText: String {
            switch self {
            case .free: return "$0/month"
            case .pro: return "$4.99/month"
            case .business: return "$14.99/month"
            }
        }
        
        var billingText: String {
            switch self {
            case .free: return "Next billing: Never"
            case .pro: return "Next billing: Monthly"
            case .business: return "Next billing: Monthly"
            }
        }
        
        func getBillingText(nextBillingDate: Date?) -> String {
            switch self {
            case .free:
                return "Next billing: Never"
            case .pro, .business:
                if let nextBilling = nextBillingDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    return "Next billing: \(formatter.string(from: nextBilling))"
                } else {
                    return "Next billing: Monthly"
                }
            }
        }
    }
} 