import UIKit
import UserNotifications

class NotificationSettingsViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Notification Settings"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose which notifications you want to receive"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let uploadCompleteSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = true
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        return switchControl
    }()
    
    private let uploadCompleteLabel: UILabel = {
        let label = UILabel()
        label.text = "Upload Notifications"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let uploadCompleteDescription: UILabel = {
        let label = UILabel()
        label.text = "Get notified when your file upload finishes (works in background too)"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let fileExpirySwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = true
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        return switchControl
    }()
    
    private let fileExpiryLabel: UILabel = {
        let label = UILabel()
        label.text = "File Expiry Warnings"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let fileExpiryDescription: UILabel = {
        let label = UILabel()
        label.text = "Get notified 24 hours before files expire"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subscriptionRenewalSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = true
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        return switchControl
    }()
    
    private let subscriptionRenewalLabel: UILabel = {
        let label = UILabel()
        label.text = "Subscription Renewal"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subscriptionRenewalDescription: UILabel = {
        let label = UILabel()
        label.text = "Get notified before subscription renewals"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let backgroundUploadSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = true
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        return switchControl
    }()
    
    private let backgroundUploadLabel: UILabel = {
        let label = UILabel()
        label.text = "Background Uploads"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let backgroundUploadDescription: UILabel = {
        let label = UILabel()
        label.text = "Continue uploading when app is in background"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Save Settings", for: .normal)
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
        loadNotificationSettings()
        requestNotificationPermission()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Notifications"
        
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
        contentView.addSubview(subtitleLabel)
                    contentView.addSubview(uploadCompleteSwitch)
            contentView.addSubview(uploadCompleteLabel)
            contentView.addSubview(uploadCompleteDescription)
            contentView.addSubview(fileExpirySwitch)
            contentView.addSubview(fileExpiryLabel)
            contentView.addSubview(fileExpiryDescription)
            contentView.addSubview(subscriptionRenewalSwitch)
            contentView.addSubview(subscriptionRenewalLabel)
            contentView.addSubview(subscriptionRenewalDescription)
        contentView.addSubview(saveButton)
        
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
            
            // Upload Complete Section
            uploadCompleteSwitch.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            uploadCompleteSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            uploadCompleteLabel.topAnchor.constraint(equalTo: uploadCompleteSwitch.topAnchor),
            uploadCompleteLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            uploadCompleteLabel.trailingAnchor.constraint(equalTo: uploadCompleteSwitch.leadingAnchor, constant: -16),
            
            uploadCompleteDescription.topAnchor.constraint(equalTo: uploadCompleteLabel.bottomAnchor, constant: 4),
            uploadCompleteDescription.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            uploadCompleteDescription.trailingAnchor.constraint(equalTo: uploadCompleteSwitch.leadingAnchor, constant: -16),
            
            // File Expiry Section
            fileExpirySwitch.topAnchor.constraint(equalTo: uploadCompleteDescription.bottomAnchor, constant: 24),
            fileExpirySwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            fileExpiryLabel.topAnchor.constraint(equalTo: fileExpirySwitch.topAnchor),
            fileExpiryLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            fileExpiryLabel.trailingAnchor.constraint(equalTo: fileExpirySwitch.leadingAnchor, constant: -16),
            
            fileExpiryDescription.topAnchor.constraint(equalTo: fileExpiryLabel.bottomAnchor, constant: 4),
            fileExpiryDescription.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            fileExpiryDescription.trailingAnchor.constraint(equalTo: fileExpirySwitch.leadingAnchor, constant: -16),
            
            // Subscription Renewal Section
            subscriptionRenewalSwitch.topAnchor.constraint(equalTo: fileExpiryDescription.bottomAnchor, constant: 24),
            subscriptionRenewalSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            subscriptionRenewalLabel.topAnchor.constraint(equalTo: subscriptionRenewalSwitch.topAnchor),
            subscriptionRenewalLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subscriptionRenewalLabel.trailingAnchor.constraint(equalTo: subscriptionRenewalSwitch.leadingAnchor, constant: -16),
            
            subscriptionRenewalDescription.topAnchor.constraint(equalTo: subscriptionRenewalLabel.bottomAnchor, constant: 4),
            subscriptionRenewalDescription.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subscriptionRenewalDescription.trailingAnchor.constraint(equalTo: subscriptionRenewalSwitch.leadingAnchor, constant: -16),
            
            // Save button
            saveButton.topAnchor.constraint(equalTo: subscriptionRenewalDescription.bottomAnchor, constant: 30),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveButtonTapped() {
        saveNotificationSettings()
        // Request notification permission if any switch is on
        if uploadCompleteSwitch.isOn || fileExpirySwitch.isOn || subscriptionRenewalSwitch.isOn {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        // Schedule a test notification to confirm
                        let content = UNMutableNotificationContent()
                        content.title = "Notifications Enabled"
                        content.body = "You will now receive notifications from QuickSend."
                        content.sound = .default
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request)
                    } else {
                        self.showNotificationPermissionAlert()
                    }
                }
            }
        }
        saveButton.setTitle("Saving...", for: .normal)
        saveButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.saveButton.setTitle("Settings Saved!", for: .normal)
            self.saveButton.backgroundColor = UIColor.systemGreen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.saveButton.setTitle("Save Settings", for: .normal)
                self.saveButton.backgroundColor = UIColor.systemBlue
                self.saveButton.isEnabled = true
            }
        }
    }
    
    // MARK: - Notification Methods
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    self.showNotificationPermissionAlert()
                }
            }
        }
    }
    
    private func showNotificationPermissionAlert() {
        let alert = UIAlertController(
            title: "Enable Notifications",
            message: "To receive upload notifications and file expiry warnings, please enable notifications in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        alert.addAction(UIAlertAction(title: "Later", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func loadNotificationSettings() {
        let defaults = UserDefaults.standard
        uploadCompleteSwitch.isOn = defaults.bool(forKey: "notification_upload_complete")
        fileExpirySwitch.isOn = defaults.bool(forKey: "notification_file_expiry")
        subscriptionRenewalSwitch.isOn = defaults.bool(forKey: "notification_subscription_renewal")
    }
    
    private func saveNotificationSettings() {
        let defaults = UserDefaults.standard
        defaults.set(uploadCompleteSwitch.isOn, forKey: "notification_upload_complete")
        defaults.set(fileExpirySwitch.isOn, forKey: "notification_file_expiry")
        defaults.set(subscriptionRenewalSwitch.isOn, forKey: "notification_subscription_renewal")
    }
}

// MARK: - Notification Helper Methods
extension NotificationSettingsViewController {
    static func sendUploadCompleteNotification(fileName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Upload Complete"
        content.body = "Your file '\(fileName)' has been uploaded successfully"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "upload_complete_\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    static func sendFileExpiryNotification(fileName: String, expiryDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "File Expiring Soon"
        content.body = "Your file '\(fileName)' will expire in 24 hours"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "file_expiry_\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    static func sendSubscriptionRenewalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Subscription Renewal"
        content.body = "Your subscription will renew in 3 days"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "subscription_renewal", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
} 