import UIKit

class SubscriptionsViewController: UIViewController {
    
    // MARK: - UI Components
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = UIColor.systemGroupedBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    // MARK: - Data
    private let subscriptionPlans = [
        SubscriptionPlan(
            id: "free",
            name: "Free",
            price: "$0",
            period: "forever",
            features: [
                "100MB file size limit",
                "7-day file expiry",
                "10 uploads per month",
                "Basic file sharing",
                "Standard support"
            ],
            color: UIColor.systemGreen
        ),
        SubscriptionPlan(
            id: "pro",
            name: "Pro",
            price: "$4.99",
            period: "month",
            features: [
                "1GB file size limit",
                "30-day file expiry",
                "100 uploads per month",
                "Large file support",
                "Priority support",
                "No ads",
                "Advanced analytics"
            ],
            color: UIColor.systemBlue
        ),
        SubscriptionPlan(
            id: "business",
            name: "Business",
            price: "$14.99",
            period: "month",
            features: [
                "5GB file size limit",
                "90-day file expiry",
                "1000 uploads per month",
                "Enterprise file sharing",
                "Custom branding",
                "API access",
                "Priority support",
                "Team management"
            ],
            color: UIColor.systemPurple
        )
    ]
    
    private var currentSubscriptionTier: User.SubscriptionTier = .free
    
    // MARK: - Models
    struct SubscriptionPlan {
        let id: String
        let name: String
        let price: String
        let period: String
        let features: [String]
        let color: UIColor
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        loadCurrentSubscription()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Subscriptions"
        
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
        tableView.register(SubscriptionTableViewCell.self, forCellReuseIdentifier: "SubscriptionCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 200
    }
    
    // MARK: - Actions
    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Data Loading
    private func loadCurrentSubscription() {
        if let user = UserManager.shared.currentUser {
            currentSubscriptionTier = user.subscriptionTier
        }
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension SubscriptionsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return subscriptionPlans.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SubscriptionCell", for: indexPath) as! SubscriptionTableViewCell
        let plan = subscriptionPlans[indexPath.row]
        let isCurrentPlan = plan.id == currentSubscriptionTier.rawValue
        cell.configure(with: plan, isCurrentPlan: isCurrentPlan)
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Available Plans"
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Your current plan is highlighted above. To change your subscription, use the 'Manage Subscription' option in Account Settings."
    }
}

// MARK: - UITableViewDelegate
extension SubscriptionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Open the main SubscriptionViewController for a consistent upgrade experience
        let subscriptionVC = SubscriptionViewController()
        let navController = UINavigationController(rootViewController: subscriptionVC)
        present(navController, animated: true)
    }
}

// MARK: - SubscriptionTableViewCell
class SubscriptionTableViewCell: UITableViewCell {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.systemGray4.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let periodLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let featuresStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let currentPlanLabel: UILabel = {
        let label = UILabel()
        label.text = "Current Plan"
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemGreen
        label.textColor = UIColor.white
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.isHidden = true
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
        backgroundColor = UIColor.clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(priceLabel)
        containerView.addSubview(periodLabel)
        containerView.addSubview(featuresStackView)
        containerView.addSubview(currentPlanLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: currentPlanLabel.leadingAnchor, constant: -12),
            
            currentPlanLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            currentPlanLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            currentPlanLabel.widthAnchor.constraint(equalToConstant: 80),
            currentPlanLabel.heightAnchor.constraint(equalToConstant: 24),
            
            priceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            priceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            periodLabel.centerYAnchor.constraint(equalTo: priceLabel.centerYAnchor),
            periodLabel.leadingAnchor.constraint(equalTo: priceLabel.trailingAnchor, constant: 4),
            periodLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            featuresStackView.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 12),
            featuresStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            featuresStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            featuresStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    func configure(with plan: SubscriptionsViewController.SubscriptionPlan, isCurrentPlan: Bool) {
        nameLabel.text = plan.name
        priceLabel.text = plan.price
        periodLabel.text = plan.period == "forever" ? "" : "/\(plan.period)"
        
        // Update border color based on current plan
        if isCurrentPlan {
            containerView.layer.borderColor = plan.color.cgColor
            containerView.backgroundColor = plan.color.withAlphaComponent(0.05)
            currentPlanLabel.isHidden = false
        } else {
            containerView.layer.borderColor = UIColor.systemGray4.cgColor
            containerView.backgroundColor = UIColor.systemBackground
            currentPlanLabel.isHidden = true
        }
        
        // Clear existing features
        featuresStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add features
        for feature in plan.features {
            let featureLabel = UILabel()
            featureLabel.text = feature
            featureLabel.font = UIFont.systemFont(ofSize: 14)
            featureLabel.textColor = UIColor.secondaryLabel
            featureLabel.numberOfLines = 0
            featuresStackView.addArrangedSubview(featureLabel)
        }
    }
} 