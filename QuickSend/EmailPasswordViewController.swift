import UIKit

class EmailPasswordViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Email & Password"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Update your account credentials"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Email Section
    private let emailSectionLabel: UILabel = {
        let label = UILabel()
        label.text = "Email Address"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let currentEmailLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let newEmailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "New email address"
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.applyQuickSendStyle()
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let updateEmailButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Update Email", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Password Section
    private let passwordSectionLabel: UILabel = {
        let label = UILabel()
        label.text = "Password"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let currentPasswordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Current password"
        textField.isSecureTextEntry = true
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.applyQuickSendStyle()
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let newPasswordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "New password"
        textField.isSecureTextEntry = true
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.applyQuickSendStyle()
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let confirmPasswordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Confirm new password"
        textField.isSecureTextEntry = true
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.applyQuickSendStyle()
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let updatePasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Update Password", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
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
        loadCurrentUserInfo()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Email & Password"
        
        // Add navigation bar button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        
        // Email section
        contentView.addSubview(emailSectionLabel)
        contentView.addSubview(currentEmailLabel)
        contentView.addSubview(newEmailTextField)
        contentView.addSubview(updateEmailButton)
        
        // Password section
        contentView.addSubview(passwordSectionLabel)
        contentView.addSubview(currentPasswordTextField)
        contentView.addSubview(newPasswordTextField)
        contentView.addSubview(confirmPasswordTextField)
        contentView.addSubview(updatePasswordButton)
        
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
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Email section
            emailSectionLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            emailSectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emailSectionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            currentEmailLabel.topAnchor.constraint(equalTo: emailSectionLabel.bottomAnchor, constant: 8),
            currentEmailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            currentEmailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            newEmailTextField.topAnchor.constraint(equalTo: currentEmailLabel.bottomAnchor, constant: 16),
            newEmailTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            newEmailTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            newEmailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            updateEmailButton.topAnchor.constraint(equalTo: newEmailTextField.bottomAnchor, constant: 16),
            updateEmailButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            updateEmailButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            updateEmailButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Password section
            passwordSectionLabel.topAnchor.constraint(equalTo: updateEmailButton.bottomAnchor, constant: 40),
            passwordSectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            passwordSectionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            currentPasswordTextField.topAnchor.constraint(equalTo: passwordSectionLabel.bottomAnchor, constant: 16),
            currentPasswordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            currentPasswordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            currentPasswordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            newPasswordTextField.topAnchor.constraint(equalTo: currentPasswordTextField.bottomAnchor, constant: 16),
            newPasswordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            newPasswordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            newPasswordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            confirmPasswordTextField.topAnchor.constraint(equalTo: newPasswordTextField.bottomAnchor, constant: 16),
            confirmPasswordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            confirmPasswordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            confirmPasswordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            updatePasswordButton.topAnchor.constraint(equalTo: confirmPasswordTextField.bottomAnchor, constant: 16),
            updatePasswordButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            updatePasswordButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            updatePasswordButton.heightAnchor.constraint(equalToConstant: 50),
            updatePasswordButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        updateEmailButton.addTarget(self, action: #selector(updateEmailTapped), for: .touchUpInside)
        updatePasswordButton.addTarget(self, action: #selector(updatePasswordTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func updateEmailTapped() {
        guard let newEmail = newEmailTextField.text, !newEmail.isEmpty else {
            showAlert(title: "Error", message: "Please enter a new email address")
            return
        }
        
        // Validate email format
        if !isValidEmail(newEmail) {
            showAlert(title: "Invalid Email", message: "Please enter a valid email address")
            return
        }
        
        // In a real app, this would call the backend API
        showAlert(title: "Success", message: "Email updated successfully!") { [weak self] in
            self?.newEmailTextField.text = ""
            self?.loadCurrentUserInfo()
        }
    }
    
    @objc private func updatePasswordTapped() {
        guard let currentPassword = currentPasswordTextField.text, !currentPassword.isEmpty else {
            showAlert(title: "Error", message: "Please enter your current password")
            return
        }
        
        guard let newPassword = newPasswordTextField.text, !newPassword.isEmpty else {
            showAlert(title: "Error", message: "Please enter a new password")
            return
        }
        
        guard let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            showAlert(title: "Error", message: "Please confirm your new password")
            return
        }
        
        if newPassword != confirmPassword {
            showAlert(title: "Error", message: "New passwords do not match")
            return
        }
        
        if newPassword.count < 6 {
            showAlert(title: "Error", message: "Password must be at least 6 characters long")
            return
        }
        
        // In a real app, this would call the backend API
        showAlert(title: "Success", message: "Password updated successfully!") { [weak self] in
            self?.currentPasswordTextField.text = ""
            self?.newPasswordTextField.text = ""
            self?.confirmPasswordTextField.text = ""
        }
    }
    
    // MARK: - Helper Methods
    private func loadCurrentUserInfo() {
        if let user = UserManager.shared.currentUser {
            currentEmailLabel.text = "Current: \(user.email)"
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
} 