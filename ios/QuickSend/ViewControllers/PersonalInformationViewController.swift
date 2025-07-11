import UIKit
import PhotosUI

class PersonalInformationViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.circle.fill")
        imageView.tintColor = UIColor.systemBlue
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 60
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = 3
        imageView.layer.borderColor = UIColor.systemBlue.cgColor
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let changePhotoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Change Photo", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.text = "Full Name"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let nameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter your full name"
        textField.borderStyle = .none
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.backgroundColor = UIColor.systemBackground
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let emailLabel: UILabel = {
        let label = UILabel()
        label.text = "Email Address"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter your email"
        textField.borderStyle = .none
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.backgroundColor = UIColor.systemBackground
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let phoneLabel: UILabel = {
        let label = UILabel()
        label.text = "Phone Number"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let phoneTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter your phone number"
        textField.borderStyle = .none
        textField.keyboardType = .phonePad
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.backgroundColor = UIColor.systemBackground
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let bioLabel: UILabel = {
        let label = UILabel()
        label.text = "Bio"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let bioTextView: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Save Changes", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    private var selectedImage: UIImage?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        loadUserData()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Personal Information"
        
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
        contentView.addSubview(changePhotoButton)
        contentView.addSubview(nameLabel)
        contentView.addSubview(nameTextField)
        contentView.addSubview(emailLabel)
        contentView.addSubview(emailTextField)
        contentView.addSubview(phoneLabel)
        contentView.addSubview(phoneTextField)
        contentView.addSubview(bioLabel)
        contentView.addSubview(bioTextView)
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
            
            // Profile image
            profileImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            profileImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 120),
            profileImageView.heightAnchor.constraint(equalToConstant: 120),
            
            // Change photo button
            changePhotoButton.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 12),
            changePhotoButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            // Name label
            nameLabel.topAnchor.constraint(equalTo: changePhotoButton.bottomAnchor, constant: 30),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Name text field
            nameTextField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            nameTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Email label
            emailLabel.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 20),
            emailLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Email text field
            emailTextField.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 8),
            emailTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emailTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Phone label
            phoneLabel.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 20),
            phoneLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            phoneLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Phone text field
            phoneTextField.topAnchor.constraint(equalTo: phoneLabel.bottomAnchor, constant: 8),
            phoneTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            phoneTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            phoneTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Bio label
            bioLabel.topAnchor.constraint(equalTo: phoneTextField.bottomAnchor, constant: 20),
            bioLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            bioLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Bio text view
            bioTextView.topAnchor.constraint(equalTo: bioLabel.bottomAnchor, constant: 8),
            bioTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            bioTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            bioTextView.heightAnchor.constraint(equalToConstant: 100),
            
            // Save button
            saveButton.topAnchor.constraint(equalTo: bioTextView.bottomAnchor, constant: 30),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        changePhotoButton.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        
        // Add tap gesture to profile image
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(changePhotoTapped))
        profileImageView.addGestureRecognizer(tapGesture)
    }
    
    private func loadUserData() {
        if let user = UserManager.shared.currentUser {
            nameTextField.text = user.name
            emailTextField.text = user.email
            
            // Load profile picture from User model first, then fallback to UserDefaults
            if let profilePictureData = user.profilePictureData,
               let image = UIImage(data: profilePictureData) {
                profileImageView.image = image
                selectedImage = image
            } else if let imageData = UserDefaults.standard.data(forKey: "userProfileImage_\(user.id)"),
                      let image = UIImage(data: imageData) {
                profileImageView.image = image
                selectedImage = image
            }
            
            // Load saved profile data
            if let profileData = UserDefaults.standard.data(forKey: "userProfile_\(user.id)"),
               let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
                phoneTextField.text = profile.phone
                bioTextView.text = profile.bio
            }
        }
    }
    
    // MARK: - Actions
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func changePhotoTapped() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func saveButtonTapped() {
        guard let name = nameTextField.text, !name.isEmpty,
              let email = emailTextField.text, !email.isEmpty else {
            showAlert(title: "Error", message: "Please fill in your name and email")
            return
        }
        
        saveButton.setTitle("Saving...", for: .normal)
        saveButton.isEnabled = false
        
        // Save profile data
        if let user = UserManager.shared.currentUser {
            let profile = UserProfile(
                phone: phoneTextField.text ?? "",
                bio: bioTextView.text ?? ""
            )
            
            // Save profile data
            if let profileData = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(profileData, forKey: "userProfile_\(user.id)")
            }
            
            // Save profile image
            if let image = selectedImage,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                UserDefaults.standard.set(imageData, forKey: "userProfileImage_\(user.id)")
                // Update user profile picture in UserManager
                UserManager.shared.updateProfilePicture(imageData)
            }
            
            // Update user name
            UserManager.shared.updateUserName(name)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.saveButton.setTitle("Save Changes", for: .normal)
            self.saveButton.isEnabled = true
            self.showAlert(title: "Success", message: "Your profile has been updated!")
            
            // Post notification to update other screens
            NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate
extension PersonalInformationViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else { return }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self?.profileImageView.image = image
                    self?.selectedImage = image
                }
            }
        }
    }
}

// MARK: - UserProfile Model
struct UserProfile: Codable {
    let phone: String
    let bio: String
} 