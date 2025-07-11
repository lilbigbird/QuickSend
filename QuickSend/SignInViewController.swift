import UIKit

class SignInViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "paperplane.circle.fill")
        imageView.tintColor = UIColor.systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome to QuickSend"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Sign in to access your account and manage subscriptions"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = UIColor.secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Email"
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .next
        textField.applyQuickSendStyle()
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let passwordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Password"
        textField.isSecureTextEntry = true
        textField.returnKeyType = .done
        textField.applyQuickSendStyle()
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let signInButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Sign In", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let signUpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create Account", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue as Guest", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.setTitleColor(UIColor.secondaryLabel, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    

    
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
        title = "Sign In"
        
        // Add navigation bar button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(logoImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(emailTextField)
        contentView.addSubview(passwordTextField)
        contentView.addSubview(signInButton)
        contentView.addSubview(signUpButton)
        contentView.addSubview(skipButton)
        
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
            
            // Logo
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Email field
            emailTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            emailTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emailTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Password field
            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
            passwordTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            passwordTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Sign in button
            signInButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 32),
            signInButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            signInButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            signInButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Sign up button
            signUpButton.topAnchor.constraint(equalTo: signInButton.bottomAnchor, constant: 16),
            signUpButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            // Skip button
            skipButton.topAnchor.constraint(equalTo: signUpButton.bottomAnchor, constant: 20),
            skipButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        
        // Set up text field delegates
        emailTextField.delegate = self
        passwordTextField.delegate = self
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func signInTapped() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please enter both email and password")
            return
        }
        
        // Sign in with UserManager
        signInButton.setTitle("Signing In...", for: .normal)
        signInButton.isEnabled = false
        
        UserManager.shared.signIn(email: email, password: password) { result in
            DispatchQueue.main.async {
                self.signInButton.setTitle("Sign In", for: .normal)
                self.signInButton.isEnabled = true
                
                switch result {
                case .success(let user):
                    self.showSuccessAndNavigateToAccount(user: user)
                case .failure(let error):
                    if let networkError = error as? NetworkError {
                        switch networkError {
                        case .serverError(401):
                            self.showAlert(title: "Sign In Failed", message: "Invalid email or password. Please check your credentials and try again.")
                        case .serverError(400):
                            self.showAlert(title: "Sign In Failed", message: "Invalid request. Please check your email format.")
                        case .networkError:
                            self.showAlert(title: "Connection Error", message: "Unable to connect to the server. Please check your internet connection and try again.")
                        default:
                            self.showAlert(title: "Sign In Failed", message: "An error occurred. Please try again later.")
                        }
                    } else {
                        self.showAlert(title: "Sign In Failed", message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    @objc private func skipTapped() {
        showGuestModeAlert()
    }
    
    @objc private func signUpTapped() {
        let signUpVC = SignUpViewController()
        let navController = UINavigationController(rootViewController: signUpVC)
        present(navController, animated: true)
    }
    
    private func createAccount(name: String, email: String, password: String) {
        signUpButton.setTitle("Creating Account...", for: .normal)
        signUpButton.isEnabled = false
        
        UserManager.shared.signUp(email: email, password: password, name: name) { result in
            DispatchQueue.main.async {
                self.signUpButton.setTitle("Create Account", for: .normal)
                self.signUpButton.isEnabled = true
                
                switch result {
                case .success(let user):
                    self.showSuccessAndNavigateToAccount(user: user)
                case .failure(let error):
                    self.showAlert(title: "Account Creation Failed", message: error.localizedDescription)
                }
            }
        }
    }
    

    
    private func showSuccessAndNavigateToAccount(user: User) {
        let alert = UIAlertController(title: "Welcome, \(user.name)!", message: "You've successfully signed in.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            self.dismiss(animated: true) {
                // Navigate to account settings
                self.navigateToAccountSettings()
            }
        })
        present(alert, animated: true)
    }
    
    private func showGuestModeAlert() {
        let alert = UIAlertController(
            title: "Continue as Guest",
            message: "You'll be using the free tier with limited features:\n• 100MB file size limit\n• 7-day file expiry\n• 10 uploads per month",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            self.dismiss(animated: true) {
                self.navigateToAccountSettings()
            }
        })
        alert.addAction(UIAlertAction(title: "Sign In Instead", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func navigateToAccountSettings() {
        let accountVC = AccountSettingsViewController()
        let navController = UINavigationController(rootViewController: accountVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    private func showNoAccountAlert() {
        let alert = UIAlertController(
            title: "No Account Found",
            message: "No account found with this email address. Please use the 'Create Account' button below to sign up.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Create Account", style: .default) { _ in
            self.signUpTapped()
        })
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - UITextFieldDelegate
extension SignInViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailTextField {
            // Move to password field
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            // Dismiss keyboard and attempt sign in
            textField.resignFirstResponder()
            signInTapped()
        }
        return true
    }
} 