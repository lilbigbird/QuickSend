import UIKit

class StorageUsageViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Storage Usage"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subscriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Free Plan"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let storageProgressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = UIColor.systemBlue
        progressView.trackTintColor = UIColor.systemGray5
        progressView.layer.cornerRadius = 4
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        return progressView
    }()
    
    private let storageInfoLabel: UILabel = {
        let label = UILabel()
        label.text = "0 MB used of 100 MB"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let storagePercentageLabel: UILabel = {
        let label = UILabel()
        label.text = "0%"
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = UIColor.systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let remainingStorageLabel: UILabel = {
        let label = UILabel()
        label.text = "100 MB remaining"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let storageCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let totalFilesLabel: UILabel = {
        let label = UILabel()
        label.text = "Total Files"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let totalFilesValueLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activeFilesLabel: UILabel = {
        let label = UILabel()
        label.text = "Active Files"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activeFilesValueLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.systemGreen
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let expiredFilesLabel: UILabel = {
        let label = UILabel()
        label.text = "Expired Files"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let expiredFilesValueLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.systemOrange
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let filesSectionLabel: UILabel = {
        let label = UILabel()
        label.text = "Recent Files"
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let filesTableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = UIColor.clear
        tableView.separatorStyle = .singleLine
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private let refreshControl = UIRefreshControl()
    
    // MARK: - Data
    private var files: [FileInfo] = []
    private var storageData: StorageData?
    
    // MARK: - Models
    struct FileInfo {
        let id: String
        let fileName: String
        let fileSize: Int64
        let uploadDate: Date
        let expiryDate: Date
        let isExpired: Bool
        
        init(from response: FileInfoResponse) {
            self.id = response.id
            self.fileName = response.fileName
            self.fileSize = response.fileSize
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            
            if let uploadDate = dateFormatter.date(from: response.uploadDate) {
                self.uploadDate = uploadDate
            } else {
                self.uploadDate = Date()
            }
            
            if let expiryDate = dateFormatter.date(from: response.expiryDate) {
                self.expiryDate = expiryDate
            } else {
                self.expiryDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days default
            }
            
            self.isExpired = response.isExpired
        }
    }
    
    struct StorageData {
        let usedStorage: Int64
        let totalStorage: Int64
        let totalFiles: Int
        let activeFiles: Int
        let expiredFiles: Int
        
        init(from response: StorageInfoResponse) {
            self.usedStorage = response.usedStorage
            self.totalStorage = response.totalStorage
            self.totalFiles = response.totalFiles
            self.activeFiles = response.activeFiles
            self.expiredFiles = response.expiredFiles
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupTableView()
        setupRefreshControl()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadStorageData()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Storage"
        
        // Add navigation bar button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(refreshButtonTapped)
        )
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(headerLabel)
        contentView.addSubview(subscriptionLabel)
        contentView.addSubview(storageProgressView)
        contentView.addSubview(storageInfoLabel)
        contentView.addSubview(storagePercentageLabel)
        contentView.addSubview(remainingStorageLabel)
        contentView.addSubview(storageCardView)
        
        storageCardView.addSubview(totalFilesLabel)
        storageCardView.addSubview(totalFilesValueLabel)
        storageCardView.addSubview(activeFilesLabel)
        storageCardView.addSubview(activeFilesValueLabel)
        storageCardView.addSubview(expiredFilesLabel)
        storageCardView.addSubview(expiredFilesValueLabel)
        
        contentView.addSubview(filesSectionLabel)
        contentView.addSubview(filesTableView)
        
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
            
            // Subscription label
            subscriptionLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            subscriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subscriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Storage progress
            storageProgressView.topAnchor.constraint(equalTo: subscriptionLabel.bottomAnchor, constant: 20),
            storageProgressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            storageProgressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            storageProgressView.heightAnchor.constraint(equalToConstant: 8),
            
            // Storage info
            storageInfoLabel.topAnchor.constraint(equalTo: storageProgressView.bottomAnchor, constant: 8),
            storageInfoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            storagePercentageLabel.topAnchor.constraint(equalTo: storageProgressView.bottomAnchor, constant: 8),
            storagePercentageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Remaining storage
            remainingStorageLabel.topAnchor.constraint(equalTo: storageInfoLabel.bottomAnchor, constant: 4),
            remainingStorageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            // Storage card
            storageCardView.topAnchor.constraint(equalTo: remainingStorageLabel.bottomAnchor, constant: 20),
            storageCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            storageCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            storageCardView.heightAnchor.constraint(equalToConstant: 100),
            
            // Total files
            totalFilesLabel.topAnchor.constraint(equalTo: storageCardView.topAnchor, constant: 16),
            totalFilesLabel.leadingAnchor.constraint(equalTo: storageCardView.leadingAnchor, constant: 16),
            
            totalFilesValueLabel.topAnchor.constraint(equalTo: totalFilesLabel.bottomAnchor, constant: 4),
            totalFilesValueLabel.leadingAnchor.constraint(equalTo: storageCardView.leadingAnchor, constant: 16),
            
            // Active files
            activeFilesLabel.topAnchor.constraint(equalTo: storageCardView.topAnchor, constant: 16),
            activeFilesLabel.centerXAnchor.constraint(equalTo: storageCardView.centerXAnchor),
            
            activeFilesValueLabel.topAnchor.constraint(equalTo: activeFilesLabel.bottomAnchor, constant: 4),
            activeFilesValueLabel.centerXAnchor.constraint(equalTo: storageCardView.centerXAnchor),
            
            // Expired files
            expiredFilesLabel.topAnchor.constraint(equalTo: storageCardView.topAnchor, constant: 16),
            expiredFilesLabel.trailingAnchor.constraint(equalTo: storageCardView.trailingAnchor, constant: -16),
            
            expiredFilesValueLabel.topAnchor.constraint(equalTo: expiredFilesLabel.bottomAnchor, constant: 4),
            expiredFilesValueLabel.trailingAnchor.constraint(equalTo: storageCardView.trailingAnchor, constant: -16),
            
            // Files section
            filesSectionLabel.topAnchor.constraint(equalTo: storageCardView.bottomAnchor, constant: 30),
            filesSectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            filesSectionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Files table
            filesTableView.topAnchor.constraint(equalTo: filesSectionLabel.bottomAnchor, constant: 16),
            filesTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            filesTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            filesTableView.heightAnchor.constraint(equalToConstant: 400),
            filesTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupTableView() {
        filesTableView.delegate = self
        filesTableView.dataSource = self
        filesTableView.register(FileInfoTableViewCell.self, forCellReuseIdentifier: "FileInfoCell")
        filesTableView.rowHeight = 80
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        filesTableView.refreshControl = refreshControl
    }
    
    // MARK: - Actions
    @objc private func refreshButtonTapped() {
        loadStorageData()
    }
    
    @objc private func refreshData() {
        loadStorageData()
    }
    
    // MARK: - Data Loading
    private func loadStorageData() {
        // Show loading state with user's subscription limits
        let user = UserManager.shared.currentUser
        let maxStorage = user?.subscriptionTier.maxFileSize ?? User.SubscriptionTier.free.maxFileSize
        
        let loadingStorageData = StorageData(from: StorageInfoResponse(
            totalFiles: 0,
            totalSizeBytes: 0,
            totalSizeMB: "0",
            totalSizeGB: "0",
            lastUpdated: ISO8601DateFormatter().string(from: Date())
        ))
        updateUI(with: loadingStorageData)
        
        // Load from backend
        NetworkService.shared.getStorageInfo { [weak self] result in
            DispatchQueue.main.async {
                self?.refreshControl.endRefreshing()
                
                switch result {
                case .success(let storageResponse):
                    let storageData = StorageData(from: storageResponse)
                    self?.storageData = storageData
                    self?.updateUI(with: storageData)
                    self?.loadFilesList()
                case .failure(let error):
                    print("Failed to load storage data: \(error)")
                    self?.showErrorAlert(message: "Failed to load storage information")
                }
            }
        }
    }
    
    private func loadFilesList() {
        NetworkService.shared.getFilesList { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fileResponses):
                    let files = fileResponses.map { FileInfo(from: $0) }
                    self?.files = files
                    self?.filesTableView.reloadData()
                case .failure(let error):
                    print("Failed to load files list: \(error)")
                    // Don't show error for files list, just keep empty
                }
            }
        }
    }
    
    private func updateUI(with storageData: StorageData) {
        // Get user's subscription tier limits
        let user = UserManager.shared.currentUser
        let maxStorage = user?.subscriptionTier.maxFileSize ?? User.SubscriptionTier.free.maxFileSize
        
        // Update subscription label
        subscriptionLabel.text = user?.subscriptionTier.displayName ?? "Free Plan"
        
        let usedMB = Double(storageData.usedStorage) / (1024 * 1024)
        let totalMB = Double(maxStorage) / (1024 * 1024)
        let percentage = totalMB > 0 ? (usedMB / totalMB) : 0
        
        storageProgressView.progress = Float(percentage)
        
        // Format storage text based on size
        let usedText = formatStorageSize(storageData.usedStorage)
        let totalText = formatStorageSize(maxStorage)
        storageInfoLabel.text = "\(usedText) used of \(totalText)"
        storagePercentageLabel.text = String(format: "%.0f%%", percentage * 100)
        
        // Calculate and display remaining storage
        let remainingStorage = maxStorage - storageData.usedStorage
        let remainingText = formatStorageSize(remainingStorage)
        remainingStorageLabel.text = "\(remainingText) remaining"
        
        totalFilesValueLabel.text = "\(storageData.totalFiles)"
        activeFilesValueLabel.text = "\(storageData.activeFiles)"
        expiredFilesValueLabel.text = "\(storageData.expiredFiles)"
        
        // Update progress color based on usage
        if percentage > 0.9 {
            storageProgressView.progressTintColor = UIColor.systemRed
        } else if percentage > 0.7 {
            storageProgressView.progressTintColor = UIColor.systemOrange
        } else {
            storageProgressView.progressTintColor = UIColor.systemBlue
        }
    }
    
    private func formatStorageSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension StorageUsageViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FileInfoCell", for: indexPath) as! FileInfoTableViewCell
        let file = files[indexPath.row]
        cell.configure(with: file)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension StorageUsageViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let file = files[indexPath.row]
        let alert = UIAlertController(title: file.fileName, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Copy Link", style: .default) { _ in
            self.copyFileLink(fileId: file.id)
        })
        
        alert.addAction(UIAlertAction(title: "Delete File", style: .destructive) { _ in
            self.deleteFile(fileId: file.id, fileName: file.fileName)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func copyFileLink(fileId: String) {
        let link = "https://api.quicksend.vip/download/\(fileId)"
        UIPasteboard.general.string = link
        
        let alert = UIAlertController(title: "Link Copied", message: "File link has been copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func deleteFile(fileId: String, fileName: String) {
        let alert = UIAlertController(title: "Delete File", message: "Are you sure you want to delete '\(fileName)'?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            NetworkService.shared.deleteFile(fileId: fileId) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.loadStorageData() // Refresh data
                    case .failure(let error):
                        print("Failed to delete file: \(error)")
                        self?.showErrorAlert(message: "Failed to delete file")
                    }
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - FileInfoTableViewCell
class FileInfoTableViewCell: UITableViewCell {
    
    private let fileNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.label
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let fileSizeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let uploadDateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(fileNameLabel)
        contentView.addSubview(fileSizeLabel)
        contentView.addSubview(uploadDateLabel)
        contentView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            fileNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            fileNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            fileNameLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -12),
            
            fileSizeLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 4),
            fileSizeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            fileSizeLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -12),
            
            uploadDateLabel.topAnchor.constraint(equalTo: fileSizeLabel.bottomAnchor, constant: 4),
            uploadDateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            uploadDateLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -12),
            uploadDateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            statusLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            statusLabel.widthAnchor.constraint(equalToConstant: 60),
            statusLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(with file: StorageUsageViewController.FileInfo) {
        fileNameLabel.text = file.fileName
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        fileSizeLabel.text = formatter.string(fromByteCount: file.fileSize)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        uploadDateLabel.text = "Uploaded: \(dateFormatter.string(from: file.uploadDate))"
        
        if file.isExpired {
            statusLabel.text = "EXPIRED"
            statusLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            statusLabel.textColor = UIColor.systemRed
        } else {
            statusLabel.text = "ACTIVE"
            statusLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
            statusLabel.textColor = UIColor.systemGreen
        }
    }
} 