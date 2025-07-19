import UIKit

class ManageSubscriptionViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Manage Subscription"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let currentPlanCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let planNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Current Plan"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let planTierLabel: UILabel = {
        let label = UILabel()
        label.text = "Free Plan"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.systemGreen
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
    
    private let featuresLabel: UILabel = {
        let label = UILabel()
        label.text = "Features:\n• 100MB file size limit\n• 7-day file expiry\n• 10 uploads per month\n• Basic file sharing"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel Subscription", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(UIColor.systemRed, for: .normal)
        button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemRed.cgColor
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let upgradeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Upgrade Plan", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        updateSubscriptionInfo()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Manage Subscription"
        
        // Add navigation bar button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(headerLabel)
        contentView.addSubview(currentPlanCardView)
        contentView.addSubview(cancelButton)
        contentView.addSubview(upgradeButton)
        
        currentPlanCardView.addSubview(planNameLabel)
        currentPlanCardView.addSubview(planTierLabel)
        currentPlanCardView.addSubview(planPriceLabel)
        currentPlanCardView.addSubview(nextBillingLabel)
        currentPlanCardView.addSubview(featuresLabel)
        
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
            
            // Current plan card
            currentPlanCardView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 20),
            currentPlanCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            currentPlanCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            currentPlanCardView.heightAnchor.constraint(equalToConstant: 280),
            
            // Plan name
            planNameLabel.topAnchor.constraint(equalTo: currentPlanCardView.topAnchor, constant: 20),
            planNameLabel.leadingAnchor.constraint(equalTo: currentPlanCardView.leadingAnchor, constant: 20),
            planNameLabel.trailingAnchor.constraint(equalTo: currentPlanCardView.trailingAnchor, constant: -20),
            
            // Plan tier
            planTierLabel.topAnchor.constraint(equalTo: planNameLabel.bottomAnchor, constant: 8),
            planTierLabel.leadingAnchor.constraint(equalTo: currentPlanCardView.leadingAnchor, constant: 20),
            planTierLabel.trailingAnchor.constraint(equalTo: currentPlanCardView.trailingAnchor, constant: -20),
            
            // Plan price
            planPriceLabel.topAnchor.constraint(equalTo: planTierLabel.bottomAnchor, constant: 4),
            planPriceLabel.leadingAnchor.constraint(equalTo: currentPlanCardView.leadingAnchor, constant: 20),
            planPriceLabel.trailingAnchor.constraint(equalTo: currentPlanCardView.trailingAnchor, constant: -20),
            
            // Next billing
            nextBillingLabel.topAnchor.constraint(equalTo: planPriceLabel.bottomAnchor, constant: 4),
            nextBillingLabel.leadingAnchor.constraint(equalTo: currentPlanCardView.leadingAnchor, constant: 20),
            nextBillingLabel.trailingAnchor.constraint(equalTo: currentPlanCardView.trailingAnchor, constant: -20),
            
            // Features
            featuresLabel.topAnchor.constraint(equalTo: nextBillingLabel.bottomAnchor, constant: 16),
            featuresLabel.leadingAnchor.constraint(equalTo: currentPlanCardView.leadingAnchor, constant: 20),
            featuresLabel.trailingAnchor.constraint(equalTo: currentPlanCardView.trailingAnchor, constant: -20),
            
            // Cancel button
            cancelButton.topAnchor.constraint(equalTo: currentPlanCardView.bottomAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cancelButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Upgrade button
            upgradeButton.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 16),
            upgradeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            upgradeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            upgradeButton.heightAnchor.constraint(equalToConstant: 50),
            upgradeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        upgradeButton.addTarget(self, action: #selector(upgradeButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func cancelButtonTapped() {
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
    
    @objc private func upgradeButtonTapped() {
        let subscriptionVC = SubscriptionViewController()
        let navController = UINavigationController(rootViewController: subscriptionVC)
        present(navController, animated: true)
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
    
    private func processCancellation() {
        cancelButton.setTitle("Cancelling...", for: .normal)
        cancelButton.isEnabled = false
        
        NetworkService.shared.cancelSubscription { [weak self] result in
            DispatchQueue.main.async {
                self?.cancelButton.setTitle("Cancel Subscription", for: .normal)
                self?.cancelButton.isEnabled = true
                
                switch result {
                case .success:
                    self?.showCancellationSuccess()
                case .failure(let error):
                    self?.showAlert(title: "Error", message: "Failed to cancel subscription: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showCancellationSuccess() {
        let alert = UIAlertController(
            title: "Subscription Cancelled",
            message: "Your subscription has been cancelled. You'll continue to have access to premium features until the end of your current billing period.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.updateSubscriptionInfo()
        })
        
        present(alert, animated: true)
    }
    
    private func updateSubscriptionInfo() {
        guard let user = UserManager.shared.currentUser else { return }
        
        planTierLabel.text = user.subscriptionTier.displayName
        planPriceLabel.text = user.subscriptionTier.priceText
        nextBillingLabel.text = user.subscriptionTier.getBillingText(nextBillingDate: user.nextBillingDate)
        
        switch user.subscriptionTier {
        case .free:
            planTierLabel.textColor = UIColor.systemGreen
            featuresLabel.text = "Features:\n• 100MB file size limit\n• 7-day file expiry\n• 10 uploads per month\n• Basic file sharing"
            cancelButton.isHidden = true
            upgradeButton.setTitle("Upgrade to Pro", for: .normal)
        case .pro:
            planTierLabel.textColor = UIColor.systemBlue
            featuresLabel.text = "Features:\n• 1GB file size limit\n• 30-day file expiry\n• 100 uploads per month\n• Priority support\n• No ads"
            cancelButton.isHidden = false
            upgradeButton.setTitle("Upgrade to Business", for: .normal)
        case .business:
            planTierLabel.textColor = UIColor.systemPurple
            featuresLabel.text = "Features:\n• 5GB file size limit\n• 90-day file expiry\n• 1000 uploads per month\n• Custom branding\n• API access\n• Priority support"
            cancelButton.isHidden = false
            upgradeButton.setTitle("Current Plan", for: .normal)
            upgradeButton.backgroundColor = UIColor.systemGray
            upgradeButton.isEnabled = false
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 