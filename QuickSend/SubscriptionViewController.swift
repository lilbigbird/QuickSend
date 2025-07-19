import UIKit
import StoreKit
import PassKit

class SubscriptionViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose Your Plan"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Unlock more features and storage"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let freePlanView: SubscriptionPlanView = {
        let planView = SubscriptionPlanView()
        planView.configure(
            title: "Free",
            price: "$0",
            period: "forever",
            features: [
                "100MB file size limit",
                "7-day file expiry",
                "10 uploads per month",
                "Basic file sharing"
            ],
            isPopular: false,
            isSelected: true
        )
        planView.translatesAutoresizingMaskIntoConstraints = false
        return planView
    }()
    
    private let proPlanView: SubscriptionPlanView = {
        let planView = SubscriptionPlanView()
        planView.configure(
            title: "Pro",
            price: User.SubscriptionTier.pro.priceText,
            period: "per month",
            features: [
                "1GB file size limit",
                "30-day file expiry",
                "100 uploads per month",
                "No ads"
            ],
            isPopular: true,
            isSelected: false
        )
        planView.translatesAutoresizingMaskIntoConstraints = false
        return planView
    }()
    
    private let businessPlanView: SubscriptionPlanView = {
        let planView = SubscriptionPlanView()
        planView.configure(
            title: "Business",
            price: User.SubscriptionTier.business.priceText,
            period: "per month",
            features: [
                "5GB file size limit",
                "90-day file expiry",
                "1000 uploads per month",
                "No ads"
            ],
            isPopular: false,
            isSelected: false
        )
        planView.translatesAutoresizingMaskIntoConstraints = false
        return planView
    }()
    
    private let subscribeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Free Trial", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let cancelSubscriptionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel Subscription", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(UIColor.systemRed, for: .normal)
        button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemRed.cgColor
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let termsLabel: UILabel = {
        let label = UILabel()
        label.text = "By subscribing, you agree to our Terms of Service and Privacy Policy. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period."
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = .center
        label.textColor = UIColor.tertiaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let currentPlanLabel: UILabel = {
        let label = UILabel()
        label.text = "Current Plan"
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let currentPlanCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let planNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Free Plan"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let planPriceLabel: UILabel = {
        let label = UILabel()
        label.text = "$0/month"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let nextBillingLabel: UILabel = {
        let label = UILabel()
        label.text = "Next billing: Never"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let planFeaturesLabel: UILabel = {
        let label = UILabel()
        label.text = "Features: 100MB files, 7-day expiry, 10 uploads/month"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Properties
    private var selectedPlan: SubscriptionPlan = .free
    private var preSelectedPlan: SubscriptionPlan?
    private var products: [Product] = []
    private var updateListenerTask: Task<Void, Error>? = nil
    
    enum SubscriptionPlan {
        case free, pro, business
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        updateCurrentPlanDisplay()
        
        // Handle pre-selected plan
        if let preSelected = preSelectedPlan {
            selectedPlan = preSelected
            updatePlanSelection()
        }
        
        // Setup StoreKit
        setupStoreKit()
    }
    
    // MARK: - Public Methods
    func preSelectPlan(_ planId: String) {
        switch planId {
        case "free":
            preSelectedPlan = .free
        case "pro":
            preSelectedPlan = .pro
        case "business":
            preSelectedPlan = .business
        default:
            preSelectedPlan = .free
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening for transaction updates
        updateListenerTask?.cancel()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Subscription"
        
        // Add navigation bar button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(headerLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(freePlanView)
        contentView.addSubview(proPlanView)
        contentView.addSubview(businessPlanView)
        contentView.addSubview(currentPlanLabel)
        contentView.addSubview(currentPlanCardView)
        contentView.addSubview(subscribeButton)
        contentView.addSubview(termsLabel)
        
        currentPlanCardView.addSubview(planNameLabel)
        currentPlanCardView.addSubview(planPriceLabel)
        currentPlanCardView.addSubview(nextBillingLabel)
        currentPlanCardView.addSubview(planFeaturesLabel)
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Free plan
            freePlanView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            freePlanView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            freePlanView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            freePlanView.heightAnchor.constraint(equalToConstant: 200),
            
            // Pro plan
            proPlanView.topAnchor.constraint(equalTo: freePlanView.bottomAnchor, constant: 12),
            proPlanView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            proPlanView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            proPlanView.heightAnchor.constraint(equalToConstant: 200),
            
            // Business plan
            businessPlanView.topAnchor.constraint(equalTo: proPlanView.bottomAnchor, constant: 12),
            businessPlanView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            businessPlanView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            businessPlanView.heightAnchor.constraint(equalToConstant: 200),
            
            // Current plan section
            currentPlanLabel.topAnchor.constraint(equalTo: businessPlanView.bottomAnchor, constant: 20),
            currentPlanLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            currentPlanLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            currentPlanCardView.topAnchor.constraint(equalTo: currentPlanLabel.bottomAnchor, constant: 12),
            currentPlanCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            currentPlanCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            currentPlanCardView.heightAnchor.constraint(equalToConstant: 140),
            
            // Plan name
            planNameLabel.topAnchor.constraint(equalTo: currentPlanCardView.topAnchor, constant: 16),
            planNameLabel.leadingAnchor.constraint(equalTo: currentPlanCardView.leadingAnchor, constant: 16),
            planNameLabel.trailingAnchor.constraint(equalTo: currentPlanCardView.trailingAnchor, constant: -16),
            
            // Plan price
            planPriceLabel.topAnchor.constraint(equalTo: planNameLabel.bottomAnchor, constant: 4),
            planPriceLabel.leadingAnchor.constraint(equalTo: currentPlanCardView.leadingAnchor, constant: 16),
            planPriceLabel.trailingAnchor.constraint(equalTo: currentPlanCardView.trailingAnchor, constant: -16),
            
            // Next billing
            nextBillingLabel.topAnchor.constraint(equalTo: planPriceLabel.bottomAnchor, constant: 4),
            nextBillingLabel.leadingAnchor.constraint(equalTo: currentPlanCardView.leadingAnchor, constant: 16),
            nextBillingLabel.trailingAnchor.constraint(equalTo: currentPlanCardView.trailingAnchor, constant: -16),
            
            // Plan features
            planFeaturesLabel.topAnchor.constraint(equalTo: nextBillingLabel.bottomAnchor, constant: 8),
            planFeaturesLabel.leadingAnchor.constraint(equalTo: currentPlanCardView.leadingAnchor, constant: 16),
            planFeaturesLabel.trailingAnchor.constraint(equalTo: currentPlanCardView.trailingAnchor, constant: -16),
            
            // Subscribe button
            subscribeButton.topAnchor.constraint(equalTo: currentPlanCardView.bottomAnchor, constant: 20),
            subscribeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subscribeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            subscribeButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Terms label
            termsLabel.topAnchor.constraint(equalTo: subscribeButton.bottomAnchor, constant: 16),
            termsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            termsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            termsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        subscribeButton.addTarget(self, action: #selector(subscribeButtonTapped), for: .touchUpInside)
        
        // Add tap gestures to plan views
        let freeTap = UITapGestureRecognizer(target: self, action: #selector(freePlanTapped))
        freePlanView.addGestureRecognizer(freeTap)
        
        let proTap = UITapGestureRecognizer(target: self, action: #selector(proPlanTapped))
        proPlanView.addGestureRecognizer(proTap)
        
        let businessTap = UITapGestureRecognizer(target: self, action: #selector(businessPlanTapped))
        businessPlanView.addGestureRecognizer(businessTap)
        
        // Add restore purchases button to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Restore",
            style: .plain,
            target: self,
            action: #selector(restorePurchasesTapped)
        )
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func subscribeButtonTapped() {
        guard let user = UserManager.shared.currentUser else { return }
        
        switch selectedPlan {
        case .free:
            if user.subscriptionTier == .free {
            showAlert(title: "Free Plan", message: "You're already on the free plan!")
            } else {
                // User wants to cancel subscription and downgrade to Free
                showCancelSubscriptionAlert()
            }
        case .pro:
            processSubscription(plan: "Pro")
        case .business:
            processSubscription(plan: "Business")
        }
    }
    
    @objc private func freePlanTapped() {
        selectedPlan = .free
        updatePlanSelection()
    }
    
    @objc private func proPlanTapped() {
        selectedPlan = .pro
        updatePlanSelection()
    }
    
    @objc private func businessPlanTapped() {
        selectedPlan = .business
        updatePlanSelection()
    }
    
    @objc private func restorePurchasesTapped() {
        Task {
            await restorePurchases()
        }
    }
    
    @objc private func cancelSubscriptionTapped() {
        let alert = UIAlertController(
            title: "Cancel Subscription",
            message: "Are you sure you want to cancel your subscription? You'll lose access to premium features at the end of your current billing period.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel Subscription", style: .destructive) { _ in
            self.showCancellationConfirmation()
        })
        alert.addAction(UIAlertAction(title: "Keep Subscription", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showCancellationConfirmation() {
        let alert = UIAlertController(
            title: "Subscription Cancelled",
            message: "Your subscription has been cancelled. You'll continue to have access to premium features until the end of your current billing period.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.selectedPlan = .free
            self.updatePlanSelection()
        })
        
        present(alert, animated: true)
    }
    
    private func updatePlanSelection() {
        freePlanView.setSelected(selectedPlan == .free)
        proPlanView.setSelected(selectedPlan == .pro)
        businessPlanView.setSelected(selectedPlan == .business)
        
        guard let user = UserManager.shared.currentUser else { return }
        
        switch selectedPlan {
        case .free:
            if user.subscriptionTier == .free {
            subscribeButton.setTitle("Current Plan", for: .normal)
            subscribeButton.backgroundColor = UIColor.systemGray
            } else {
                // User is on Pro/Business and wants to downgrade to Free
                subscribeButton.setTitle("Cancel Current Subscription", for: .normal)
                subscribeButton.backgroundColor = UIColor.systemRed
            }
        case .pro:
            subscribeButton.setTitle("Subscribe to Pro - \(User.SubscriptionTier.pro.priceText)", for: .normal)
            subscribeButton.backgroundColor = UIColor.systemBlue
        case .business:
            subscribeButton.setTitle("Subscribe to Business - \(User.SubscriptionTier.business.priceText)", for: .normal)
            subscribeButton.backgroundColor = UIColor.systemBlue
        }
    }
    
    private func processSubscription(plan: String) {
        Task {
            await purchaseSubscription(plan: plan)
        }
    }
    
    private func showSuccessAlert(plan: String) {
        let alert = UIAlertController(
            title: "Welcome to \(plan)!",
            message: "Your subscription has been activated. Enjoy your new features!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Great!", style: .default) { _ in
            // Dismiss the subscription view to return to account settings
            self.dismiss(animated: true) {
                // Force update the account settings view
                NotificationCenter.default.post(name: NSNotification.Name("SubscriptionTierChanged"), object: nil)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showCancelSubscriptionAlert() {
        let alert = UIAlertController(
            title: "Cancel Subscription",
            message: "You will now be navigated to your subscriptions page in the App Store to cancel your Quick-Send subscription.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Subscriptions", style: .default) { _ in
            self.openSubscriptionSettings()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func openSubscriptionSettings() {
        // Try to open Settings app to Apple ID > Subscriptions
        // Use the App Store subscription management URL
        if let subscriptionUrl = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(subscriptionUrl) { success in
                if success {
                    print("Successfully opened App Store subscription management")
                } else {
                    // Fallback to general settings if App Store URL doesn't work
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl) { success in
                            if success {
                                // Show instructions after opening Settings
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.showSubscriptionInstructions()
                                }
                            } else {
                                print("Failed to open Settings app")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func showSubscriptionInstructions() {
        let alert = UIAlertController(
            title: "Manage Subscriptions",
            message: "In Settings, tap your Apple ID at the top, then tap 'Subscriptions' to manage your Quick-Send subscription.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateCurrentPlanDisplay() {
        guard let user = UserManager.shared.currentUser else { return }
        
        planNameLabel.text = user.subscriptionTier.displayName
        planPriceLabel.text = user.subscriptionTier.priceText
        nextBillingLabel.text = user.subscriptionTier.getBillingText(nextBillingDate: user.nextBillingDate)
        
        switch user.subscriptionTier {
        case .free:
            planFeaturesLabel.text = "Features: 100MB files, 7-day expiry, 10 uploads/month"
            currentPlanCardView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        case .pro:
            planFeaturesLabel.text = "Features: 1GB files, 30-day expiry, 100 uploads/month, No ads"
            currentPlanCardView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        case .business:
            planFeaturesLabel.text = "Features: 5GB files, 90-day expiry, 1000 uploads/month, No ads"
            currentPlanCardView.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        }
        
        // Update selected plan to match current subscription
        selectedPlan = user.subscriptionTier == .free ? .free : (user.subscriptionTier == .pro ? .pro : .business)
        updatePlanSelection()
    }
    
    // MARK: - StoreKit Integration
    private func setupStoreKit() {
        Task {
            await loadProducts()
        }
    }
    
    private func loadProducts() async {
        do {
            let productIdentifiers = Set([
                "com.quicksend.pro.monthly1",
                "com.quicksend.business.monthly2"
            ])
            
            print("Loading products with identifiers: \(productIdentifiers)")
            let storeProducts = try await Product.products(for: productIdentifiers)
            
            print("Loaded \(storeProducts.count) products:")
            for product in storeProducts {
                print("- \(product.id): \(product.displayName) - \(product.displayPrice)")
            }
            
            DispatchQueue.main.async {
                self.products = storeProducts
                self.updatePlanPrices()
            }
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    private func updatePlanPrices() {
        for product in products {
            switch product.id {
            case "com.quicksend.pro.monthly1":
                proPlanView.updatePrice("\(product.displayPrice)/month")
            case "com.quicksend.business.monthly2":
                businessPlanView.updatePrice("\(product.displayPrice)/month")
            default:
                break
            }
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                await self.handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try result.payloadValue
            
            // Update the user's subscription based on the transaction
            await updateSubscriptionFromTransaction(transaction)
            
            // Finish the transaction
            await transaction.finish()
        } catch {
            print("Transaction failed verification: \(error)")
        }
    }
    
    private func updateSubscriptionFromTransaction(_ transaction: Transaction) async {
        let tier: User.SubscriptionTier
        
        switch transaction.productID {
        case "com.quicksend.pro.monthly1":
            tier = .pro
        case "com.quicksend.business.monthly2":
            tier = .business
        default:
            return
        }
        
        // Update user subscription
        UserManager.shared.updateSubscriptionTier(tier)
        
        // Post notification for UI updates
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("SubscriptionTierChanged"), object: nil)
        }
    }
    
    private func purchaseSubscription(plan: String) async {
        let productId: String
        let tier: User.SubscriptionTier
        
        switch plan {
        case "Pro":
            productId = "com.quicksend.pro.monthly1"
            tier = .pro
        case "Business":
            productId = "com.quicksend.business.monthly2"
            tier = .business
        default:
            return
        }
        
        print("Attempting to purchase: \(productId) for plan: \(plan)")
        print("Available products: \(products.map { $0.id })")
        
        guard let product = products.first(where: { $0.id == productId }) else {
            print("Product not found: \(productId)")
            DispatchQueue.main.async {
                self.showAlert(title: "Error", message: "Product not available. Please try again later.")
            }
            return
        }
        
        print("Found product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
        
        do {
            print("Starting purchase for product: \(product.id)")
            print("Apple Pay available: \(PKPaymentAuthorizationController.canMakePayments())")
            print("Apple Pay setup: \(PKPaymentAuthorizationController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex]))")
            let result = try await product.purchase()
            
            print("Purchase result received: \(result)")
            
            switch result {
            case .success(let verification):
                print("Purchase successful, verifying transaction...")
                let transaction = try checkVerified(verification)
                print("Transaction verified: \(transaction.id)")
                
                // Update user subscription
                UserManager.shared.updateSubscriptionTier(tier)
                print("User subscription updated to: \(tier)")
                
                // Post notification for UI updates
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("SubscriptionTierChanged"), object: nil)
                    self.updateCurrentPlanDisplay() // Update the current plan display immediately
                    self.showSuccessAlert(plan: plan)
                }
                
                // Finish the transaction
                await transaction.finish()
                print("Transaction finished")
                
            case .userCancelled:
                print("Purchase cancelled by user")
                DispatchQueue.main.async {
                    self.showAlert(title: "Purchase Cancelled", message: "The purchase was cancelled.")
                }
                
            case .pending:
                print("Purchase pending")
                DispatchQueue.main.async {
                    self.showAlert(title: "Purchase Pending", message: "Your purchase is pending approval.")
                }
                
            @unknown default:
                print("Unknown purchase result")
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "An unknown error occurred.")
                }
            }
        } catch {
            print("Purchase failed with error: \(error)")
            DispatchQueue.main.async {
                self.showAlert(title: "Purchase Failed", message: "Failed to complete purchase: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func restorePurchases() async {
        do {
            try await AppStore.sync()
            
            // Check for any active subscriptions
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    await updateSubscriptionFromTransaction(transaction)
                }
            }
            
            DispatchQueue.main.async {
                self.showAlert(title: "Restore Complete", message: "Your purchases have been restored successfully.")
            }
        } catch {
            DispatchQueue.main.async {
                self.showAlert(title: "Restore Failed", message: "Failed to restore purchases: \(error.localizedDescription)")
            }
        }
    }
    
    private enum StoreError: LocalizedError {
        case failedVerification
        
        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "Transaction verification failed"
            }
        }
    }
}



// MARK: - SubscriptionPlanView
class SubscriptionPlanView: UIView {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.systemGray4.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let popularBadge: UILabel = {
        let label = UILabel()
        label.text = "MOST POPULAR"
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.systemOrange
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.textColor = UIColor.systemBlue
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let periodLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let featuresStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        addSubview(containerView)
        containerView.addSubview(popularBadge)
        containerView.addSubview(titleLabel)
        containerView.addSubview(priceLabel)
        containerView.addSubview(periodLabel)
        containerView.addSubview(featuresStackView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            popularBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            popularBadge.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            popularBadge.heightAnchor.constraint(equalToConstant: 16),
            popularBadge.widthAnchor.constraint(equalToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            priceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            priceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            periodLabel.centerYAnchor.constraint(equalTo: priceLabel.centerYAnchor),
            periodLabel.leadingAnchor.constraint(equalTo: priceLabel.trailingAnchor, constant: 4),
            
            featuresStackView.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 16),
            featuresStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            featuresStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            featuresStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    func configure(title: String, price: String, period: String, features: [String], isPopular: Bool, isSelected: Bool) {
        titleLabel.text = title
        // Combine price and period into one label, hide the separate period label
        priceLabel.text = price
        periodLabel.isHidden = true
        popularBadge.isHidden = !isPopular
        
        // Clear existing features
        featuresStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add features
        for feature in features {
            let featureView = createFeatureView(text: feature)
            featuresStackView.addArrangedSubview(featureView)
        }
        
        setSelected(isSelected)
    }
    
    private func createFeatureView(text: String) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let checkmarkImageView = UIImageView()
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
        checkmarkImageView.tintColor = UIColor.systemGreen
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(checkmarkImageView)
        containerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            checkmarkImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 16),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 16),
            
            label.leadingAnchor.constraint(equalTo: checkmarkImageView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            label.topAnchor.constraint(equalTo: containerView.topAnchor),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    func setSelected(_ selected: Bool) {
        if selected {
            containerView.layer.borderColor = UIColor.systemBlue.cgColor
            containerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
        } else {
            containerView.layer.borderColor = UIColor.systemGray4.cgColor
            containerView.backgroundColor = UIColor.systemBackground
        }
    }
    
    func updatePrice(_ price: String) {
        priceLabel.text = price
    }
} 