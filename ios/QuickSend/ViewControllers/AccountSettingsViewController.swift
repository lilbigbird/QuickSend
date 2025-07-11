import UIKit

class AccountSettingsViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.circle.fill")
        imageView.tintColor = UIColor.systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 50
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.text = "John Doe"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emailLabel: UILabel = {
        let label = UILabel()
        label.text = "john.doe@example.com"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = UIColor.secondaryLabel
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
        ["Personal Information", "Email & Password"],
        ["Subscriptions", "Manage Subscription", "Billing History"],
        ["Notifications", "Storage Usage", "About QuickSend", "Rate App", "Sign Out"]
    ]
    
    private let sectionTitles = ["Account", "Subscription", "Settings"]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupSettingsStackView()
        setupActions()
        updateUserInfo()
        
        // Add notification observer for profile updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(profileUpdated),
            name: NSNotification.Name("ProfileUpdated"),
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
        
        contentView.addSubview(profileImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(emailLabel)
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
            
            // Profile image
            profileImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            profileImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 100),
            profileImageView.heightAnchor.constraint(equalToConstant: 100),
            
            // Name label
            nameLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Email label
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            emailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subscription status view
            subscriptionStatusView.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 24),
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
    
    @objc private func profileUpdated() {
        updateUserInfo()
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
            headerLabel.backgroundColor = UIColor.systemGroupedBackground
            headerLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let headerContainer = UIView()
            headerContainer.backgroundColor = UIColor.systemGroupedBackground
            headerContainer.addSubview(headerLabel)
            headerContainer.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
                headerLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
                headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
                headerLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8)
            ])
            
            settingsStackView.addArrangedSubview(headerContainer)
            
            // Add section items
            for (itemIndex, item) in section.enumerated() {
                let button = createSettingsButton(title: item, isLastInSection: itemIndex == section.count - 1)
                settingsStackView.addArrangedSubview(button)
            }
            
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
        button.backgroundColor = UIColor.secondarySystemGroupedBackground
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Customize Sign Out button
        if title == "Sign Out" {
            button.setTitleColor(UIColor.systemRed, for: .normal)
        } else {
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
        }
        
        // Add bottom border if not last in section
        if !isLastInSection {
            let borderView = UIView()
            borderView.backgroundColor = UIColor.systemGray5
            borderView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(borderView)
            
            NSLayoutConstraint.activate([
                borderView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
                borderView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
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
        case "Personal Information":
            let personalInfoVC = PersonalInformationViewController()
            navigationController?.pushViewController(personalInfoVC, animated: true)
        case "Email & Password":
            showEmailPasswordSettings()
        case "Subscriptions":
            let subscriptionVC = SubscriptionViewController()
            let navController = UINavigationController(rootViewController: subscriptionVC)
            present(navController, animated: true)
        case "Manage Subscription":
            let manageSubscriptionVC = ManageSubscriptionViewController()
            let navController = UINavigationController(rootViewController: manageSubscriptionVC)
            present(navController, animated: true)
        case "Billing History":
            let billingHistoryVC = BillingHistoryViewController()
            let navController = UINavigationController(rootViewController: billingHistoryVC)
            present(navController, animated: true)
        case "About QuickSend":
            showAboutQuickSend()
        case "Notifications":
            showNotificationSettings()
        case "Storage Usage":
            showStorageUsage()
        case "Rate App":
            rateApp()
        case "Sign Out":
            showSignOutConfirmation()
        default:
            showComingSoon(title)
        }
    }
    
    private func showStorageUsage() {
        let storageVC = StorageUsageViewController()
        navigationController?.pushViewController(storageVC, animated: true)
    }
    
    private func rateApp() {
        let alert = UIAlertController(title: "Rate QuickSend", message: "Thanks for using QuickSend! Please rate us on the App Store.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Rate Now", style: .default) { _ in
            // Open App Store
            if let url = URL(string: "https://apps.apple.com/us/app/quick-send/id6748480371") {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Later", style: .cancel))
        present(alert, animated: true)
    }
    

    
    private func showEmailPasswordSettings() {
        let emailPasswordVC = EmailPasswordViewController()
        let navController = UINavigationController(rootViewController: emailPasswordVC)
        present(navController, animated: true)
    }
    

    
    private func showAboutQuickSend() {
        let alert = UIAlertController(
            title: "About QuickSend",
            message: "QuickSend v1.0.0\n\nQuickSend is your ultimate file sharing companion! Share files instantly with anyone, anywhere. Whether it's photos, documents, or videos, QuickSend makes sharing effortless and secure.\n\nKey Features:\n• Lightning-fast uploads\n• Secure file sharing\n• Easy-to-use interface\n• Works on any device\n• No registration required for recipients\n\nPerfect for work, school, or personal use. Just select a file, upload, and share the link - it's that simple!\n\n© 2024 QuickSend. All rights reserved.",
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
            nameLabel.text = user.name
            emailLabel.text = user.email
            subscriptionLabel.text = user.subscriptionTier.displayName
            
            // Update profile picture
            if let profilePictureData = user.profilePictureData,
               let image = UIImage(data: profilePictureData) {
                profileImageView.image = image
            } else {
                profileImageView.image = UIImage(systemName: "person.circle.fill")
                profileImageView.tintColor = UIColor.systemBlue
            }
            
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
        }
    }
    
    private func showSignOutConfirmation() {
        let alert = UIAlertController(
            title: "Sign Out",
            message: "Are you sure you want to sign out?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { _ in
            UserManager.shared.signOut()
            self.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showComingSoon(_ feature: String) {
        let alert = UIAlertController(title: "Coming Soon", message: "\(feature) will be available in a future update!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 