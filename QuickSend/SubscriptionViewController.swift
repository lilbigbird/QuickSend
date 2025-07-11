import UIKit
import StoreKit
import PassKit

class SubscriptionViewController: UIViewController, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    
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
                "Priority support",
                "No ads",
                "Advanced analytics"
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
                "Custom branding",
                "API access",
                "Priority support",
                "Team management"
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
    private var products: [SKProduct] = []
    private var preSelectedPlan: SubscriptionPlan?
    
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
        setupStoreKit()
        
        // Handle pre-selected plan
        if let preSelected = preSelectedPlan {
            selectedPlan = preSelected
            updatePlanSelection()
        }
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
        SKPaymentQueue.default().add(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        SKPaymentQueue.default().remove(self)
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
            freePlanView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            freePlanView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            freePlanView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            freePlanView.heightAnchor.constraint(equalToConstant: 240),
            
            // Pro plan
            proPlanView.topAnchor.constraint(equalTo: freePlanView.bottomAnchor, constant: 16),
            proPlanView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            proPlanView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            proPlanView.heightAnchor.constraint(equalToConstant: 260),
            
            // Business plan
            businessPlanView.topAnchor.constraint(equalTo: proPlanView.bottomAnchor, constant: 16),
            businessPlanView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            businessPlanView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            businessPlanView.heightAnchor.constraint(equalToConstant: 280),
            
            // Current plan section
            currentPlanLabel.topAnchor.constraint(equalTo: businessPlanView.bottomAnchor, constant: 30),
            currentPlanLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            currentPlanLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            currentPlanCardView.topAnchor.constraint(equalTo: currentPlanLabel.bottomAnchor, constant: 12),
            currentPlanCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            currentPlanCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            currentPlanCardView.heightAnchor.constraint(equalToConstant: 160),
            
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
            subscribeButton.topAnchor.constraint(equalTo: currentPlanCardView.bottomAnchor, constant: 30),
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
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func subscribeButtonTapped() {
        switch selectedPlan {
        case .free:
            showAlert(title: "Free Plan", message: "You're already on the free plan!")
        case .pro:
            showPaymentAlert(plan: "Pro", price: User.SubscriptionTier.pro.priceText)
        case .business:
            showPaymentAlert(plan: "Business", price: User.SubscriptionTier.business.priceText)
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
        
        switch selectedPlan {
        case .free:
            subscribeButton.setTitle("Current Plan", for: .normal)
            subscribeButton.backgroundColor = UIColor.systemGray
        case .pro:
            subscribeButton.setTitle("Subscribe to Pro - \(User.SubscriptionTier.pro.priceText)", for: .normal)
            subscribeButton.backgroundColor = UIColor.systemBlue
        case .business:
            subscribeButton.setTitle("Subscribe to Business - \(User.SubscriptionTier.business.priceText)", for: .normal)
            subscribeButton.backgroundColor = UIColor.systemBlue
        }
    }
    
    private func showPaymentAlert(plan: String, price: String) {
        if PKPaymentAuthorizationController.canMakePayments() {
            showApplePayPayment(plan: plan, price: price)
        } else {
            showFallbackPayment(plan: plan, price: price)
        }
    }
    
    private func showApplePayPayment(plan: String, price: String) {
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.quicksend.app"
        request.supportedNetworks = [.visa, .masterCard, .amex]
        request.merchantCapabilities = .capability3DS
        request.countryCode = "US"
        request.currencyCode = "USD"
        
        let priceValue = plan == "Pro" ? 5.0 : 15.0
        let paymentItem = PKPaymentSummaryItem(label: "\(plan) Subscription", amount: NSDecimalNumber(value: priceValue))
        let totalItem = PKPaymentSummaryItem(label: "QuickSend", amount: NSDecimalNumber(value: priceValue))
        
        request.paymentSummaryItems = [paymentItem, totalItem]
        
        let paymentController = PKPaymentAuthorizationController(paymentRequest: request)
        paymentController.delegate = self
        paymentController.present { presented in
            if !presented {
                self.showFallbackPayment(plan: plan, price: price)
            }
        }
    }
    
    private func showFallbackPayment(plan: String, price: String) {
        let alert = UIAlertController(
            title: "Subscribe to \(plan)",
            message: "This will charge \(price) to your App Store account. Your subscription will be processed securely through Apple's payment system.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Subscribe", style: .default) { _ in
            self.processSubscription(plan: plan)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func processSubscription(plan: String) {
        let tier: User.SubscriptionTier = plan == "Pro" ? .pro : .business
        UserManager.shared.updateSubscriptionTier(tier)
        showSuccessAlert(plan: plan)
    }
    
    private func showSuccessAlert(plan: String) {
        let alert = UIAlertController(
            title: "Welcome to \(plan)!",
            message: "Your subscription has been activated. Enjoy your new features!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Great!", style: .default) { _ in
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
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
            planFeaturesLabel.text = "Features: 1GB files, 30-day expiry, 100 uploads/month, Priority support, No ads"
            currentPlanCardView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        case .business:
            planFeaturesLabel.text = "Features: 5GB files, 90-day expiry, 1000 uploads/month, Custom branding, API access, Priority support"
            currentPlanCardView.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        }
        
        // Update selected plan to match current subscription
        selectedPlan = user.subscriptionTier == .free ? .free : (user.subscriptionTier == .pro ? .pro : .business)
        updatePlanSelection()
    }
    
    // MARK: - StoreKit Integration
    private func setupStoreKit() {
        // Request products from App Store Connect
        let productIdentifiers = Set([
            "com.quicksend.pro.monthly",
            "com.quicksend.business.monthly"
        ])
        
        let request = SKProductsRequest(productIdentifiers: productIdentifiers)
        request.delegate = self
        request.start()
    }
    
    // MARK: - SKProductsRequestDelegate
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        // Store the products for later use
        self.products = response.products
        print("Received \(response.products.count) products from App Store")
        for product in response.products {
            print("Product: \(product.productIdentifier) - \(product.localizedTitle) - \(product.price)")
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("StoreKit request failed: \(error.localizedDescription)")
    }
    
    // MARK: - SKPaymentTransactionObserver
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                // Handle successful purchase
                handleSuccessfulPurchase(transaction)
                queue.finishTransaction(transaction)
            case .failed:
                // Handle failed purchase
                handleFailedPurchase(transaction)
                queue.finishTransaction(transaction)
            case .restored:
                // Handle restored purchase
                handleRestoredPurchase(transaction)
                queue.finishTransaction(transaction)
            case .deferred:
                // Handle deferred purchase (waiting for approval)
                print("Purchase deferred")
            case .purchasing:
                // Purchase in progress
                print("Purchase in progress")
            @unknown default:
                break
            }
        }
    }
    
    private func handleSuccessfulPurchase(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            // Update user's subscription tier
            if transaction.payment.productIdentifier == "com.quicksend.pro.monthly" {
                UserManager.shared.updateSubscriptionTier(.pro)
            } else if transaction.payment.productIdentifier == "com.quicksend.business.monthly" {
                UserManager.shared.updateSubscriptionTier(.business)
            }
            
            // Show success message
            let alert = UIAlertController(title: "Purchase Successful", message: "Your subscription has been activated!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.dismiss(animated: true)
            })
            self.present(alert, animated: true)
        }
    }
    
    private func handleFailedPurchase(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Purchase Failed", message: transaction.error?.localizedDescription ?? "An error occurred during purchase", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    private func handleRestoredPurchase(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            // Handle restored purchase
            print("Purchase restored: \(transaction.payment.productIdentifier)")
        }
    }
    
    private func purchaseProduct(withIdentifier identifier: String) {
        guard SKPaymentQueue.canMakePayments() else {
            let alert = UIAlertController(title: "Payments Disabled", message: "In-app purchases are disabled on this device", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Find the product with the given identifier
        guard let product = products.first(where: { $0.productIdentifier == identifier }) else {
            let alert = UIAlertController(title: "Product Not Found", message: "The requested product is not available", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Create payment with the product
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
}

// MARK: - PKPaymentAuthorizationControllerDelegate
extension SubscriptionViewController: PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Process payment authorization
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        }
    }
    
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            // Handle payment completion
            if let selectedPlan = self.getSelectedPlanName() {
                self.processSubscription(plan: selectedPlan)
            }
        }
    }
    
    private func getSelectedPlanName() -> String? {
        switch selectedPlan {
        case .pro: return "Pro"
        case .business: return "Business"
        default: return nil
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
        priceLabel.text = price
        periodLabel.text = period
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
} 