import UIKit
import PhotosUI
import GoogleMobileAds

class HomeViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Quick-Send"
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor.systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Share files instantly"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let fileSelectionView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemYellow // Make it obvious
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 3
        view.layer.borderColor = UIColor.red.cgColor // Bright red border
        view.isUserInteractionEnabled = true
        // Note: Dashed borders need to be implemented with CAShapeLayer
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let fileSelectionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemGray6
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.setTitle("", for: .normal) // No text on button, we'll add it as a separate label
        button.isUserInteractionEnabled = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let fileSelectionLabel: UILabel = {
        let label = UILabel()
        label.text = "Tap to Select File"
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.textColor = UIColor.systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let fileIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "doc.badge.plus")
        imageView.tintColor = UIColor.systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let selectedFileLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let accountButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "person.circle"), for: .normal)
        button.tintColor = UIColor.systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let generateLinkButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Generate Link", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.isEnabled = false
        button.alpha = 0.6
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let linkOutputView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray4.cgColor
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let linkLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let copyLinkButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Copy Link", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = UIColor.systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.isUserInteractionEnabled = true
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Share", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = UIColor.systemOrange
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.isUserInteractionEnabled = true
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = UIColor.systemBlue
        progress.trackTintColor = UIColor.systemGray5
        progress.layer.cornerRadius = 3
        progress.clipsToBounds = true
        progress.isHidden = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
    private let progressLabel: UILabel = {
        let label = UILabel()
        label.text = "Uploading..."
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Properties
    private var selectedFileURL: URL?
    private var generatedLink: String?
    private var bannerAdView: BannerView?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        setupAdMob()
        setupSubscriptionNotifications()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAdDisplay()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    

    
    @objc private func fileSelectionTapped() {
        presentFilePicker()
    }
    
    @objc private func accountButtonTapped() {
        // Create guest user if no user exists
        if UserManager.shared.currentUser == nil {
            UserManager.shared.createGuestUser()
        }
        
        // Always show account settings (now works without authentication)
        let accountVC = AccountSettingsViewController()
        let navController = UINavigationController(rootViewController: accountVC)
        present(navController, animated: true)
    }
    
    @objc private func generateLinkTapped() {
        guard let fileURL = selectedFileURL else { return }
        
        // Show interstitial ad for free users before upload
        showInterstitialAdIfNeeded()
        
        uploadFile(fileURL: fileURL)
    }
    
    @objc private func copyLinkTapped() {
        guard let link = generatedLink else { return }
        UIPasteboard.general.string = link
        
        let alert = UIAlertController(title: "Link Copied", message: "The link has been copied to your clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func shareLinkTapped() {
        guard let link = generatedLink else { return }
        
        let activityViewController = UIActivityViewController(activityItems: [link], applicationActivities: nil)
        present(activityViewController, animated: true)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Add navigation bar button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "person.circle"),
            style: .plain,
            target: self,
            action: #selector(accountButtonTapped)
        )
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add title and subtitle to main view (outside scroll view)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        
        // Add file selection button to main view (outside scroll view)
        view.addSubview(fileSelectionButton)
        view.addSubview(fileIconImageView)
        view.addSubview(fileSelectionLabel)
        view.addSubview(selectedFileLabel)
        view.addSubview(generateLinkButton)
        
        // Move link output view and buttons outside scroll view
        view.addSubview(linkOutputView)
        view.addSubview(copyLinkButton)
        view.addSubview(shareButton)
        
        // Add progress indicators to main view (not scroll view)
        view.addSubview(progressView)
        view.addSubview(progressLabel)
        
        linkOutputView.addSubview(linkLabel)
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure scroll view to allow touch gestures
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = false
        scrollView.isScrollEnabled = true
        scrollView.bounces = false // Prevent bouncing that might interfere with touches
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view (starts below the buttons)
            scrollView.topAnchor.constraint(equalTo: shareButton.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -100), // Space for banner ads
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // File selection button
            fileSelectionButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            fileSelectionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            fileSelectionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            fileSelectionButton.heightAnchor.constraint(equalToConstant: 120),
            
            // File icon
            fileIconImageView.centerXAnchor.constraint(equalTo: fileSelectionButton.centerXAnchor),
            fileIconImageView.centerYAnchor.constraint(equalTo: fileSelectionButton.centerYAnchor, constant: -10),
            fileIconImageView.widthAnchor.constraint(equalToConstant: 40),
            fileIconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            // File selection label
            fileSelectionLabel.topAnchor.constraint(equalTo: fileIconImageView.bottomAnchor, constant: 8),
            fileSelectionLabel.leadingAnchor.constraint(equalTo: fileSelectionButton.leadingAnchor, constant: 16),
            fileSelectionLabel.trailingAnchor.constraint(equalTo: fileSelectionButton.trailingAnchor, constant: -16),
            
            // Selected file label
            selectedFileLabel.topAnchor.constraint(equalTo: fileSelectionButton.bottomAnchor, constant: 16),
            selectedFileLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            selectedFileLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Generate link button
            generateLinkButton.topAnchor.constraint(equalTo: selectedFileLabel.bottomAnchor, constant: 20),
            generateLinkButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            generateLinkButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            generateLinkButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Link label
            linkLabel.topAnchor.constraint(equalTo: linkOutputView.topAnchor, constant: 16),
            linkLabel.leadingAnchor.constraint(equalTo: linkOutputView.leadingAnchor, constant: 16),
            linkLabel.trailingAnchor.constraint(equalTo: linkOutputView.trailingAnchor, constant: -16),
            
            // Copy link button (outside scroll view)
            copyLinkButton.topAnchor.constraint(equalTo: linkOutputView.bottomAnchor, constant: 16),
            copyLinkButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            copyLinkButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.45),
            copyLinkButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Share button (outside scroll view)
            shareButton.topAnchor.constraint(equalTo: linkOutputView.bottomAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            shareButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.45),
            shareButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Link output view
            linkOutputView.topAnchor.constraint(equalTo: generateLinkButton.bottomAnchor, constant: 16),
            linkOutputView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            linkOutputView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            linkOutputView.heightAnchor.constraint(equalToConstant: 80),
            
            // Progress view (below link output view)
            progressView.topAnchor.constraint(equalTo: linkOutputView.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 6),
            
            // Progress label (above progress bar)
            progressLabel.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -8),
            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        // Use tap gesture recognizer for file selection (works better with scroll view)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(fileSelectionTapped))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.cancelsTouchesInView = false
        fileSelectionButton.addGestureRecognizer(tapGesture)
        
        // Also add target action as backup
        fileSelectionButton.addTarget(self, action: #selector(fileSelectionTapped), for: .touchUpInside)
        
        generateLinkButton.addTarget(self, action: #selector(generateLinkTapped), for: .touchUpInside)
        copyLinkButton.addTarget(self, action: #selector(copyLinkTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareLinkTapped), for: .touchUpInside)
    }
    

    
    // MARK: - File Picker
    private func presentFilePicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    // MARK: - File Upload
    private func uploadFile(fileURL: URL) {
        // Check upload limits before starting upload
        guard let user = UserManager.shared.currentUser else {
            showError("User not found")
            return
        }
        
        // Check monthly upload limit
        if !checkUploadLimit() {
            return
        }
        
        // Check file size limit
        getFileSizeSafe(fileURL: fileURL) { [weak self] fileSize in
            guard let self = self else { return }
            
            if let fileSize = fileSize {
                if !self.validateFileSize(fileSize) {
                    return
                }
            }
            
            // All checks passed, proceed with upload
            DispatchQueue.main.async {
                self.performUpload(fileURL: fileURL)
            }
        }
    }
    
    private func performUpload(fileURL: URL) {
        // Show loading state immediately
        generateLinkButton.isEnabled = false
        progressView.isHidden = false
        progressLabel.isHidden = false
        progressView.progress = 0.0
        progressLabel.text = "Starting upload..."
        
        // Start security access immediately
        let securityAccessGranted = fileURL.startAccessingSecurityScopedResource()
        
        // Use optimized S3 upload directly - let NetworkService handle file size detection
        NetworkService.shared.uploadFileOptimized(fileURL: fileURL, progressHandler: { [weak self] progress in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.progressView.progress = progress
                let percentage = Int(progress * 100)
                self.progressLabel.text = "Uploading... \(percentage)%"
            }
        }) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Release security access after upload
                if securityAccessGranted {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                
                self.generateLinkButton.isEnabled = true
                self.progressView.isHidden = true
                self.progressLabel.isHidden = true
                
                switch result {
                case .success(let response):
                    // Increment upload count on successful upload
                    self.incrementUploadCount()
                    self.generatedLink = response.downloadLink
                    self.showLinkOutput()
                    
                    // Show interstitial ad for free users after successful upload
                    self.showInterstitialAdIfNeeded()
                case .failure(let error):
                    // Handle specific error types
                    if case .fileTooLarge(let message) = error {
                        self.showFileTooLargeError(message)
                    } else {
                        self.showError(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    // Safe file size detection for large files (prevents crashes)
    private func getFileSizeSafe(fileURL: URL, completion: @escaping (Int64?) -> Void) {
        // Run file size detection on background queue to prevent UI blocking
        DispatchQueue.global(qos: .utility).async {
            var fileSize: Int64?
            
            // Only try resource values - safest approach for large files
            // Avoid FileManager.attributesOfItem which can cause memory issues with large files
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                if let size = resourceValues.fileSize, size > 0 {
                    fileSize = Int64(size)
                }
            }
            
            // If resource values failed, try FileManager as fallback
            if fileSize == nil {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    if let size = attributes[.size] as? Int64, size > 0 {
                        fileSize = size
                    }
                } catch {
                    // File size detection failed, will proceed anyway
                }
            }
            
            // Return result on main queue
            DispatchQueue.main.async {
                completion(fileSize)
            }
        }
    }
    
    private func validateFileSize(_ fileSize: Int64) -> Bool {
        let user = UserManager.shared.currentUser
        let maxFileSize = user?.subscriptionTier.maxFileSize ?? User.SubscriptionTier.free.maxFileSize
        
        if fileSize > maxFileSize {
            let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            let maxSizeString = ByteCountFormatter.string(fromByteCount: maxFileSize, countStyle: .file)
            let planName = user?.subscriptionTier.displayName ?? "Free"
            
            let alert = UIAlertController(
                title: "File Too Large",
                message: "Your \(planName) plan has a \(maxSizeString) file size limit. The selected file is \(fileSizeString).\n\nUpgrade your plan to upload larger files.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Upgrade Today", style: .default) { _ in
                self.showUpgradeOptions()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            present(alert, animated: true)
            return false
        }
        
        return true
    }
    
    private func checkUploadLimit() -> Bool {
        guard let user = UserManager.shared.currentUser else { return false }
        
        // Get current month's upload count from UserDefaults
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let uploadCountKey = "uploadCount_\(currentYear)_\(currentMonth)"
        
        let currentUploadCount = UserDefaults.standard.integer(forKey: uploadCountKey)
        let maxUploads = user.subscriptionTier.maxUploadsPerMonth
        
        if currentUploadCount >= maxUploads {
            let planName = user.subscriptionTier.displayName
            let alert = UIAlertController(
                title: "Monthly Upload Limit Reached",
                message: "You've reached your monthly upload limit of \(maxUploads) files for your \(planName) plan.\n\nUpgrade your plan to upload more files.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Upgrade Today", style: .default) { _ in
                self.showUpgradeOptions()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            present(alert, animated: true)
            return false
        }
        
        return true
    }
    
    private func incrementUploadCount() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        let uploadCountKey = "uploadCount_\(currentYear)_\(currentMonth)"
        
        let currentCount = UserDefaults.standard.integer(forKey: uploadCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: uploadCountKey)
    }
    
    private func showUpgradeOptions() {
        let alert = UIAlertController(
            title: "Upgrade Your Plan",
            message: "Choose a plan that supports larger files:",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Pro - \(User.SubscriptionTier.pro.priceText)", style: .default) { _ in
            self.navigateToSubscription(plan: "Pro")
        })
        alert.addAction(UIAlertAction(title: "Business - \(User.SubscriptionTier.business.priceText)", style: .default) { _ in
            self.navigateToSubscription(plan: "Business")
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func navigateToSubscription(plan: String) {
        let subscriptionVC = SubscriptionViewController()
        subscriptionVC.preSelectPlan(plan.lowercased())
        let navController = UINavigationController(rootViewController: subscriptionVC)
        present(navController, animated: true)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Upload Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showFileTooLargeError(_ message: String) {
        let alert = UIAlertController(
            title: "File Too Large",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Upgrade Today", style: .default) { _ in
            self.showUpgradeOptions()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showLinkOutput() {
        linkLabel.text = generatedLink
        linkOutputView.isHidden = false
        
        // Show and enable buttons
        copyLinkButton.isHidden = false
        shareButton.isHidden = false
        copyLinkButton.isEnabled = true
        shareButton.isEnabled = true
        copyLinkButton.alpha = 1.0
        shareButton.alpha = 1.0
        copyLinkButton.isUserInteractionEnabled = true
        shareButton.isUserInteractionEnabled = true
        
        // Force layout update
        linkOutputView.layoutIfNeeded()
    }
    
    private func updateFileSelection(fileName: String) {
        selectedFileLabel.text = "Selected: \(fileName)"
        selectedFileLabel.isHidden = false
        generateLinkButton.isEnabled = true
        generateLinkButton.alpha = 1.0
    }
    
    // MARK: - AdMob Integration
    private func setupAdMob() {
        // Load interstitial ad for free users
        AdMobService.shared.loadInterstitialAd()
        
        // Setup banner ad for free users
        if AdMobService.shared.shouldShowAds(for: UserManager.shared.currentUser) {
            bannerAdView = AdMobService.shared.createBannerAdView(for: UserManager.shared.currentUser)
            if let bannerAdView = bannerAdView {
                view.addSubview(bannerAdView)
                bannerAdView.translatesAutoresizingMaskIntoConstraints = false
                setupBannerAdConstraints()
            }
        }
    }
    
    private func setupBannerAdConstraints() {
        guard let bannerAdView = bannerAdView else { return }
        
        NSLayoutConstraint.activate([
            bannerAdView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerAdView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerAdView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bannerAdView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func showInterstitialAdIfNeeded() {
        AdMobService.shared.showInterstitialAdIfNeeded(from: self, for: UserManager.shared.currentUser)
    }
    
    // MARK: - Subscription Update Handling
    private func setupSubscriptionNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subscriptionTierChanged),
            name: NSNotification.Name("SubscriptionTierChanged"),
            object: nil
        )
    }
    
    @objc private func subscriptionTierChanged() {
        print("HomeViewController: Subscription tier changed notification received")
        DispatchQueue.main.async {
            self.updateAdDisplay()
        }
    }
    
    private func updateAdDisplay() {
        print("HomeViewController: Updating ad display for tier: \(UserManager.shared.currentUser?.subscriptionTier.displayName ?? "nil")")
        
        // Remove existing banner ad if any
        bannerAdView?.removeFromSuperview()
        bannerAdView = nil
        
        // Check if we should show ads for current user
        if AdMobService.shared.shouldShowAds(for: UserManager.shared.currentUser) {
            print("HomeViewController: Showing ads for free user")
            // User is on free tier - show ads
            bannerAdView = AdMobService.shared.createBannerAdView(for: UserManager.shared.currentUser)
            if let bannerAdView = bannerAdView {
                view.addSubview(bannerAdView)
                bannerAdView.translatesAutoresizingMaskIntoConstraints = false
                setupBannerAdConstraints()
            }
            // Load interstitial for free users
            AdMobService.shared.loadInterstitialAd()
        } else {
            print("HomeViewController: Hiding ads for Pro/Business user")
            // User is on Pro/Business tier - no ads
            // Reset the first ad flag so they get clean experience if they downgrade later
            AdMobService.shared.resetFirstAdFlag()
        }
    }

}

// MARK: - UIDocumentPickerDelegate
extension HomeViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Start security access immediately
        let securityAccessGranted = url.startAccessingSecurityScopedResource()
        
        let user = UserManager.shared.currentUser
        let tier = user?.subscriptionTier ?? .free
        
        // Check file size
        getFileSizeSafe(fileURL: url) { [weak self] fileSize in
            // Release security access after file size check
            if securityAccessGranted {
                url.stopAccessingSecurityScopedResource()
            }
            
            guard let self = self else { return }
            
            // If we can't get file size, proceed anyway (user can try upload)
            if let fileSize = fileSize {
                if fileSize > tier.maxFileSize {
                    let maxSizeString = ByteCountFormatter.string(fromByteCount: tier.maxFileSize, countStyle: .file)
                    let alert = UIAlertController(title: "File Too Large", message: "Your current plan only allows files up to \(maxSizeString). Please upgrade your subscription.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    return
                }
            }
            
            // All checks passed: update UI and state
            self.selectedFileURL = url
            self.updateFileSelection(fileName: url.lastPathComponent)
            self.generateLinkButton.isEnabled = true
            self.generateLinkButton.alpha = 1.0
        }
    }
} 