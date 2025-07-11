import UIKit

class BillingHistoryViewController: UIViewController {
    
    // MARK: - UI Components
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = UIColor.systemGroupedBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    // MARK: - Data
    private var billingHistory: [BillingRecord] = []
    
    // MARK: - Models
    struct BillingRecord {
        let id: String
        let date: Date
        let amount: Double
        let description: String
        let type: BillingType
        let status: BillingStatus
        
        enum BillingType {
            case subscription
            case upgrade
            case renewal
            
            var displayName: String {
                switch self {
                case .subscription: return "Subscription"
                case .upgrade: return "Upgrade"
                case .renewal: return "Renewal"
                }
            }
        }
        
        enum BillingStatus {
            case completed
            case pending
            case failed
            
            var displayName: String {
                switch self {
                case .completed: return "Completed"
                case .pending: return "Pending"
                case .failed: return "Failed"
                }
            }
            
            var color: UIColor {
                switch self {
                case .completed: return UIColor.systemGreen
                case .pending: return UIColor.systemOrange
                case .failed: return UIColor.systemRed
                }
            }
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        loadBillingHistory()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Billing History"
        
        // Add navigation bar button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(BillingHistoryTableViewCell.self, forCellReuseIdentifier: "BillingCell")
        tableView.rowHeight = 80
    }
    
    // MARK: - Actions
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Data Loading
    private func loadBillingHistory() {
        // Load real billing history from backend (empty for now)
        billingHistory = []
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension BillingHistoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return billingHistory.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BillingCell", for: indexPath) as! BillingHistoryTableViewCell
        let record = billingHistory[indexPath.row]
        cell.configure(with: record)
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Transaction History"
    }
}

// MARK: - UITableViewDelegate
extension BillingHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let record = billingHistory[indexPath.row]
        let alert = UIAlertController(
            title: "Transaction Details",
            message: "ID: \(record.id)\nDate: \(formatDate(record.date))\nAmount: $\(String(format: "%.2f", record.amount))\nType: \(record.type.displayName)\nStatus: \(record.status.displayName)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - BillingHistoryTableViewCell
class BillingHistoryTableViewCell: UITableViewCell {
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = UIColor.label
        label.numberOfLines = 2
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
    
    private let amountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textColor = UIColor.label
        label.textAlignment = .right
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
        contentView.addSubview(dateLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(amountLabel)
        contentView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dateLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -12),
            
            descriptionLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: amountLabel.leadingAnchor, constant: -12),
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            statusLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            statusLabel.widthAnchor.constraint(equalToConstant: 60),
            statusLabel.heightAnchor.constraint(equalToConstant: 24),
            
            amountLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            amountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            amountLabel.widthAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    func configure(with record: BillingHistoryViewController.BillingRecord) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        dateLabel.text = formatter.string(from: record.date)
        
        descriptionLabel.text = record.description
        
        if record.amount > 0 {
            amountLabel.text = "$\(String(format: "%.2f", record.amount))"
            amountLabel.textColor = UIColor.label
        } else {
            amountLabel.text = "Free"
            amountLabel.textColor = UIColor.systemGreen
        }
        
        statusLabel.text = record.status.displayName
        statusLabel.backgroundColor = record.status.color.withAlphaComponent(0.1)
        statusLabel.textColor = record.status.color
    }
} 