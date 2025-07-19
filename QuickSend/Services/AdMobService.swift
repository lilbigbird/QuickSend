import UIKit
import GoogleMobileAds

class AdMobService: NSObject {
    static let shared = AdMobService()
    
    private var interstitialAd: InterstitialAd?
    private var bannerAdView: BannerView?
    private var hasShownFirstAd = false
    
    // AdMob IDs - Production
    private let bannerAdUnitID = "ca-app-pub-7795204884488645/3434584560" // Banner ad unit ID
    private let interstitialAdUnitID = "ca-app-pub-7795204884488645/1298719272" // Interstitial ad unit ID
    
    private override init() {
        super.init()
        initializeAdMob()
    }
    
    // MARK: - Initialization
    private func initializeAdMob() {
        MobileAds.shared.start()
    }
    
    // MARK: - Banner Ads
    func createBannerAdView(for user: User?) -> BannerView? {
        // Only show ads for free users
        guard let user = user, user.subscriptionTier == .free else {
            return nil
        }
        
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = bannerAdUnitID
        bannerView.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        bannerView.delegate = self
        
        let request = Request()
        bannerView.load(request)
        
        return bannerView
    }
    
    func shouldShowAds(for user: User?) -> Bool {
        // Only show ads for free users
        guard let user = user else { 
            return false 
        }
        return user.subscriptionTier == .free
    }
    
    // MARK: - Interstitial Ads
    func loadInterstitialAd() {
        // Only load ads for free users
        guard UserManager.shared.currentUser?.subscriptionTier == .free else { 
            return 
        }
        
        let request = Request()
        InterstitialAd.load(with: interstitialAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad: \(error)")
                return
            }
            self?.interstitialAd = ad
        }
    }
    
    func showInterstitialAdIfNeeded(from viewController: UIViewController, for user: User?) {
        // Only show ads for free users
        guard let user = user, user.subscriptionTier == .free else { 
            return 
        }
        
        // Skip the first ad, show from second use onwards
        if !hasShownFirstAd {
            hasShownFirstAd = true
            loadInterstitialAd() // Load for next time
            return
        }
        
        if let interstitialAd = interstitialAd {
            interstitialAd.present(from: viewController)
            self.interstitialAd = nil // Clear after showing
            loadInterstitialAd() // Load next ad
        } else {
            loadInterstitialAd() // Try to load if not ready
        }
    }
    
    func resetFirstAdFlag() {
        hasShownFirstAd = false
    }
}

// MARK: - BannerViewDelegate
extension AdMobService: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("Banner ad loaded successfully")
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("Banner ad failed to load: \(error)")
    }
} 