import UIKit
import PhotosUI

class HomeViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "QuickSend"
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
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.systemBlue.cgColor
        // Note: Dashed borders need to be implemented with CAShapeLayer
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
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
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(fileSelectionView)
        contentView.addSubview(selectedFileLabel)
        contentView.addSubview(generateLinkButton)
        contentView.addSubview(progressView)
        contentView.addSubview(progressLabel)
        contentView.addSubview(linkOutputView)
        contentView.addSubview(activityIndicator)
        
        fileSelectionView.addSubview(fileIconImageView)
        fileSelectionView.addSubview(fileSelectionLabel)
        
        linkOutputView.addSubview(linkLabel)
        linkOutputView.addSubview(copyLinkButton)
        linkOutputView.addSubview(shareButton)
        
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
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // File selection view
            fileSelectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            fileSelectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            fileSelectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            fileSelectionView.heightAnchor.constraint(equalToConstant: 120),
            
            // File icon
            fileIconImageView.centerXAnchor.constraint(equalTo: fileSelectionView.centerXAnchor),
            fileIconImageView.centerYAnchor.constraint(equalTo: fileSelectionView.centerYAnchor, constant: -10),
            fileIconImageView.widthAnchor.constraint(equalToConstant: 40),
            fileIconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            // File selection label
            fileSelectionLabel.topAnchor.constraint(equalTo: fileIconImageView.bottomAnchor, constant: 8),
            fileSelectionLabel.leadingAnchor.constraint(equalTo: fileSelectionView.leadingAnchor, constant: 16),
            fileSelectionLabel.trailingAnchor.constraint(equalTo: fileSelectionView.trailingAnchor, constant: -16),
            
            // Selected file label
            selectedFileLabel.topAnchor.constraint(equalTo: fileSelectionView.bottomAnchor, constant: 16),
            selectedFileLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            selectedFileLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Generate link button
            generateLinkButton.topAnchor.constraint(equalTo: selectedFileLabel.bottomAnchor, constant: 30),
            generateLinkButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            generateLinkButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            generateLinkButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Progress view
            progressView.topAnchor.constraint(equalTo: generateLinkButton.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // Progress label
            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            progressLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Link output view
            linkOutputView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 20),
            linkOutputView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            linkOutputView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            linkOutputView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Link label
            linkLabel.topAnchor.constraint(equalTo: linkOutputView.topAnchor, constant: 16),
            linkLabel.leadingAnchor.constraint(equalTo: linkOutputView.leadingAnchor, constant: 16),
            linkLabel.trailingAnchor.constraint(equalTo: linkOutputView.trailingAnchor, constant: -16),
            
            // Copy link button
            copyLinkButton.topAnchor.constraint(equalTo: linkLabel.bottomAnchor, constant: 16),
            copyLinkButton.leadingAnchor.constraint(equalTo: linkOutputView.leadingAnchor, constant: 16),
            copyLinkButton.widthAnchor.constraint(equalTo: linkOutputView.widthAnchor, multiplier: 0.45),
            copyLinkButton.heightAnchor.constraint(equalToConstant: 40),
            copyLinkButton.bottomAnchor.constraint(equalTo: linkOutputView.bottomAnchor, constant: -16),
            
            // Share button
            shareButton.topAnchor.constraint(equalTo: linkLabel.bottomAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: linkOutputView.trailingAnchor, constant: -16),
            shareButton.widthAnchor.constraint(equalTo: linkOutputView.widthAnchor, multiplier: 0.45),
            shareButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupActions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(fileSelectionTapped))
        fileSelectionView.addGestureRecognizer(tapGesture)
        
        generateLinkButton.addTarget(self, action: #selector(generateLinkTapped), for: .touchUpInside)
        copyLinkButton.addTarget(self, action: #selector(copyLinkTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareLinkTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func fileSelectionTapped() {
        presentFilePicker()
    }
    
    @objc private func accountButtonTapped() {
        if UserManager.shared.isSignedIn {
            // User is signed in, show account settings
            let accountVC = AccountSettingsViewController()
            let navController = UINavigationController(rootViewController: accountVC)
            present(navController, animated: true)
        } else {
            // User is not signed in, show sign-in screen
            let signInVC = SignInViewController()
            let navController = UINavigationController(rootViewController: signInVC)
            present(navController, animated: true)
        }
    }
    
    @objc private func generateLinkTapped() {
        guard let fileURL = selectedFileURL else { return }
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
    
    // MARK: - File Picker
    private func presentFilePicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    // MARK: - File Upload
    private func uploadFile(fileURL: URL) {
        print("Starting upload for file: \(fileURL.lastPathComponent)")
        print("File path: \(fileURL.path)")
        print("File URL: \(fileURL)")
        
        // Check file size before upload
        guard let fileSize = getFileSize(fileURL: fileURL) else {
            showError("Cannot determine file size")
            return
        }
        
        // Validate file size against user's subscription limits
        guard validateFileSize(fileSize) else {
            return
        }
        
        // Ensure we have access to the security-scoped resource
        guard fileURL.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            showError("Cannot access the selected file")
            return
        }
        
        defer { fileURL.stopAccessingSecurityScopedResource() }
        
        activityIndicator.startAnimating()
        generateLinkButton.isEnabled = false
        progressView.isHidden = false
        progressLabel.isHidden = false
        progressView.progress = 0.0
        
        NetworkService.shared.uploadFile(fileURL: fileURL, progressHandler: { progress in
            DispatchQueue.main.async {
                self.progressView.progress = progress
                self.progressLabel.text = "Uploading... \(Int(progress * 100))%"
            }
        }) { result in
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.generateLinkButton.isEnabled = true
                self.progressView.isHidden = true
                self.progressLabel.isHidden = true
                
                switch result {
                case .success(let response):
                    print("Upload successful: \(response.downloadLink)")
                    self.generatedLink = response.downloadLink
                    self.showLinkOutput()
                case .failure(let error):
                    print("Upload failed: \(error.localizedDescription)")
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func getFileSize(fileURL: URL) -> Int64? {
        do {
            // Try to access the security-scoped resource first
            if fileURL.startAccessingSecurityScopedResource() {
                defer { fileURL.stopAccessingSecurityScopedResource() }
                
                // Try multiple approaches to get file size
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                    return Int64(resourceValues.fileSize ?? 0)
                }
                
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
                    return attributes[.size] as? Int64
                }
                
                // Try with resolved URL
                if let resolvedURL = try? fileURL.resolvingSymlinksInPath() {
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: resolvedURL.path) {
                        return attributes[.size] as? Int64
                    }
                }
            } else {
                // Fallback for non-security-scoped URLs
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                    return Int64(resourceValues.fileSize ?? 0)
                }
                
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
                    return attributes[.size] as? Int64
                }
            }
            
            print("All file size methods failed for URL: \(fileURL)")
            return nil
        } catch {
            print("Error getting file size: \(error)")
            return nil
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
            
            alert.addAction(UIAlertAction(title: "Upgrade Plan", style: .default) { _ in
                self.showUpgradeOptions()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            present(alert, animated: true)
            return false
        }
        
        return true
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
    
    private func showLinkOutput() {
        linkLabel.text = generatedLink
        linkOutputView.isHidden = false
        
        // Scroll to link output
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let bottomOffset = CGPoint(x: 0, y: self.scrollView.contentSize.height - self.scrollView.bounds.height)
            self.scrollView.setContentOffset(bottomOffset, animated: true)
        }
    }
    
    private func updateFileSelection(fileName: String) {
        selectedFileLabel.text = "Selected: \(fileName)"
        selectedFileLabel.isHidden = false
        generateLinkButton.isEnabled = true
        generateLinkButton.alpha = 1.0
    }
}

// MARK: - UIDocumentPickerDelegate
extension HomeViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        print("Selected file URL: \(url)")
        print("URL path: \(url.path)")
        print("URL absoluteString: \(url.absoluteString)")
        
        // For document picker URLs, we need to access the security-scoped resource
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Get file size for display
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                
                selectedFileURL = url
                updateFileSelection(fileName: "\(url.lastPathComponent) (\(fileSizeString))")
                print("File selected successfully: \(url.lastPathComponent)")
            } catch {
                print("Error getting file attributes: \(error)")
                selectedFileURL = url
                updateFileSelection(fileName: url.lastPathComponent)
            }
        } else {
            print("Failed to access security-scoped resource")
            selectedFileURL = url
            updateFileSelection(fileName: url.lastPathComponent)
        }
    }
} 