import UIKit

class AccountSettingsViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "paperplane.circle.fill")
        imageView.tintColor = UIColor.systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 50
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let welcomeLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome to Quick-Send"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subscriptionStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGreen.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let subscriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Free Plan"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = UIColor.systemGreen
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let upgradeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Upgrade to Pro", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let settingsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.backgroundColor = UIColor.systemGroupedBackground
        stackView.layer.cornerRadius = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    

    
    // MARK: - Properties
    private var tableTopConstraint: NSLayoutConstraint?
    private let settingsData = [
        ["Subscriptions", "Manage Subscription"], // Removed account-related items
        ["Notifications", "About Quick-Send", "Rate App"]
    ]
    
    private let sectionTitles = ["Subscription", "Settings"]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupSettingsStackView()
        setupActions()
        
        // Update user info after everything is set up
        DispatchQueue.main.async {
            self.updateUserInfo()
        }
        
        // Listen for subscription updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subscriptionUpdated),
            name: NSNotification.Name("SubscriptionTierChanged"),
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Remove observer when view disappears
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("SubscriptionTierChanged"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Account Settings"
        
        // Add navigation bar button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(logoImageView)
        contentView.addSubview(welcomeLabel)
        contentView.addSubview(subscriptionStatusView)
        contentView.addSubview(upgradeButton)
        contentView.addSubview(settingsStackView)
        
        subscriptionStatusView.addSubview(subscriptionLabel)
        
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
            
            // Logo image
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),
            
            // Welcome label
            welcomeLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 16),
            welcomeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            welcomeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subscription status view
            subscriptionStatusView.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 24),
            subscriptionStatusView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subscriptionStatusView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            subscriptionStatusView.heightAnchor.constraint(equalToConstant: 60),
            
            // Subscription label
            subscriptionLabel.centerXAnchor.constraint(equalTo: subscriptionStatusView.centerXAnchor),
            subscriptionLabel.centerYAnchor.constraint(equalTo: subscriptionStatusView.centerYAnchor),
            
            // Upgrade button
            upgradeButton.topAnchor.constraint(equalTo: subscriptionStatusView.bottomAnchor, constant: 16),
            upgradeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            upgradeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            upgradeButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Settings stack view
            settingsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            settingsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            settingsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupSettingsStackView() {
        createSettingsSections()
    }
    
    private func setupActions() {
        upgradeButton.addTarget(self, action: #selector(upgradeButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func upgradeButtonTapped() {
        let subscriptionVC = SubscriptionViewController()
        let navController = UINavigationController(rootViewController: subscriptionVC)
        present(navController, animated: true)
    }
    
    @objc private func subscriptionUpdated() {
        // Update UI when subscription changes
        DispatchQueue.main.async {
            self.updateUserInfo()
        }
    }
    
    // MARK: - Settings Creation
    private func createSettingsSections() {
        // Clear existing views
        settingsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (sectionIndex, section) in settingsData.enumerated() {
            // Add section header
            let headerLabel = UILabel()
            headerLabel.text = sectionTitles[sectionIndex]
            headerLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            headerLabel.textColor = UIColor.label
            headerLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let headerContainer = UIView()
            headerContainer.backgroundColor = UIColor.systemBackground
            headerContainer.addSubview(headerLabel)
            headerContainer.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 4),
                headerLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -4),
                headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
                headerLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8)
            ])
            
            settingsStackView.addArrangedSubview(headerContainer)
            
            // Create section container
            let sectionContainer = UIView()
            sectionContainer.backgroundColor = UIColor.secondarySystemGroupedBackground
            sectionContainer.layer.cornerRadius = 12
            sectionContainer.translatesAutoresizingMaskIntoConstraints = false
            
            // Create section stack view
            let sectionStackView = UIStackView()
            sectionStackView.axis = .vertical
            sectionStackView.spacing = 0
            sectionStackView.translatesAutoresizingMaskIntoConstraints = false
            sectionContainer.addSubview(sectionStackView)
            
            // Add section items
            for (itemIndex, item) in section.enumerated() {
                let button = createSettingsButton(title: item, isLastInSection: itemIndex == section.count - 1)
                sectionStackView.addArrangedSubview(button)
            }
            
            // Constrain section stack view
            NSLayoutConstraint.activate([
                sectionStackView.topAnchor.constraint(equalTo: sectionContainer.topAnchor),
                sectionStackView.leadingAnchor.constraint(equalTo: sectionContainer.leadingAnchor),
                sectionStackView.trailingAnchor.constraint(equalTo: sectionContainer.trailingAnchor),
                sectionStackView.bottomAnchor.constraint(equalTo: sectionContainer.bottomAnchor)
            ])
            
            settingsStackView.addArrangedSubview(sectionContainer)
            
            // Add spacing between sections (except for last section)
            if sectionIndex < settingsData.count - 1 {
                let spacerView = UIView()
                spacerView.backgroundColor = UIColor.systemBackground
                spacerView.translatesAutoresizingMaskIntoConstraints = false
                spacerView.heightAnchor.constraint(equalToConstant: 20).isActive = true
                settingsStackView.addArrangedSubview(spacerView)
            }
        }
    }
    
    private func createSettingsButton(title: String, isLastInSection: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.contentHorizontalAlignment = .left
        button.backgroundColor = UIColor.clear
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add proper padding for text
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        button.setTitleColor(UIColor.label, for: .normal)
        // Add chevron
        let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevronImageView.tintColor = UIColor.systemGray3
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            chevronImageView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        // Add bottom border if not last in section
        if !isLastInSection {
            let borderView = UIView()
            borderView.backgroundColor = UIColor.systemGray5
            borderView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(borderView)
            
            NSLayoutConstraint.activate([
                borderView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
                borderView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
                borderView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                borderView.heightAnchor.constraint(equalToConstant: 0.5)
            ])
        }
        
        // Set height
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        // Add action
        button.addTarget(self, action: #selector(settingsButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    @objc private func settingsButtonTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        
        switch title {
        case "Subscriptions":
            let subscriptionVC = SubscriptionViewController()
            let navController = UINavigationController(rootViewController: subscriptionVC)
            present(navController, animated: true)
        case "Manage Subscription":
            let manageSubscriptionVC = ManageSubscriptionViewController()
            let navController = UINavigationController(rootViewController: manageSubscriptionVC)
            present(navController, animated: true)
        case "About Quick-Send":
            showAboutQuickSend()
        case "Notifications":
            showNotificationSettings()
        case "Rate App":
            rateApp()
        default:
            showComingSoon(title)
        }
    }
    
    private func rateApp() {
        let alert = UIAlertController(title: "Rate Quick-Send", message: "Thanks for using Quick-Send! Please rate us on the App Store.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Rate Now", style: .default) { _ in
            // Open App Store
            if let url = URL(string: "https://apps.apple.com/us/app/quick-send/id6748480371") {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Later", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showAboutQuickSend() {
        let alert = UIAlertController(
            title: "About Quick-Send",
            message: "\nQuick-Send is your ultimate file sharing companion! Share files instantly with anyone, anywhere. Whether it's photos, documents, or videos, Quick-Send makes sharing effortless and secure.\n\nKey Features:\n• Lightning-fast uploads\n• Secure file sharing\n• Easy-to-use interface\n• Works on any device\n• No registration required for recipients\n\nPerfect for work, school, or personal use. Just select a file, upload, and share the link - it's that simple!\n\n© 2025 BirdStudios. All rights reserved.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showNotificationSettings() {
        let notificationVC = NotificationSettingsViewController()
        let navController = UINavigationController(rootViewController: notificationVC)
        present(navController, animated: true)
    }
    
    private func updateUserInfo() {
        if let user = UserManager.shared.currentUser {
            subscriptionLabel.text = user.subscriptionTier.displayName
            
            // Deactivate existing constraint
            tableTopConstraint?.isActive = false
            
            // Update subscription status view color and upgrade button based on tier
            switch user.subscriptionTier {
            case .free:
                subscriptionStatusView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
                subscriptionStatusView.layer.borderColor = UIColor.systemGreen.cgColor
                subscriptionLabel.textColor = UIColor.systemGreen
                upgradeButton.setTitle("Upgrade to Pro", for: .normal)
                upgradeButton.isHidden = false
                // Set stack view constraint to upgrade button
                tableTopConstraint = settingsStackView.topAnchor.constraint(equalTo: upgradeButton.bottomAnchor, constant: 20)
            case .pro:
                subscriptionStatusView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
                subscriptionStatusView.layer.borderColor = UIColor.systemBlue.cgColor
                subscriptionLabel.textColor = UIColor.systemBlue
                upgradeButton.setTitle("Upgrade to Business", for: .normal)
                upgradeButton.isHidden = false
                // Set stack view constraint to upgrade button
                tableTopConstraint = settingsStackView.topAnchor.constraint(equalTo: upgradeButton.bottomAnchor, constant: 20)
            case .business:
                subscriptionStatusView.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
                subscriptionStatusView.layer.borderColor = UIColor.systemPurple.cgColor
                subscriptionLabel.textColor = UIColor.systemPurple
                upgradeButton.isHidden = true
                // Set stack view constraint to subscription status view
                tableTopConstraint = settingsStackView.topAnchor.constraint(equalTo: subscriptionStatusView.bottomAnchor, constant: 20)
            }
            
            // Activate new constraint
            tableTopConstraint?.isActive = true
        } else {
            // Handle case when no user is signed in
            subscriptionLabel.text = "Free Plan"
            
            // Set default styling
            subscriptionStatusView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
            subscriptionStatusView.layer.borderColor = UIColor.systemGreen.cgColor
            subscriptionLabel.textColor = UIColor.systemGreen
            upgradeButton.setTitle("Upgrade to Pro", for: .normal)
            upgradeButton.isHidden = false
            
            // Set default constraint
            tableTopConstraint?.isActive = false
            tableTopConstraint = settingsStackView.topAnchor.constraint(equalTo: upgradeButton.bottomAnchor, constant: 20)
            tableTopConstraint?.isActive = true
        }
    }
    
    private func showComingSoon(_ feature: String) {
        let alert = UIAlertController(title: "Coming Soon", message: "\(feature) will be available in a future update!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 