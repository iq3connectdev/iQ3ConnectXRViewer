import UIKit

final class TabStripView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private(set) var tabs: [Tab] = []
    private(set) var selectedTab: Tab?

    var onSelectTab: ((Tab) -> Void)?
    var onCloseTab: ((Tab) -> Void)?
    var onNewTab: (() -> Void)?
    /// Called after a drag reorders a tab: (fromIndex, toIndex).
    var onReorderTab: ((Int, Int) -> Void)?
    /// Called when the user taps the tabs-count button (opens the tab list popup).
    var onTabsButtonTapped: (() -> Void)?

    private let collectionView: UICollectionView
    private let addButton = UIButton(type: .system)
    private let tabsButton = UIButton(type: .system)

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 6
        layout.minimumInteritemSpacing = 6
        layout.sectionInset = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 4)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        overrideUserInterfaceStyle = .light
        backgroundColor = Constant.chromeBackgroundColor()
        // Subtle shadow at the bottom of the strip so the chrome feels layered above the page.
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.masksToBounds = false

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(TabStripCell.self, forCellWithReuseIdentifier: "stripCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)

        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.tintColor = .darkGray
        addButton.accessibilityLabel = "New tab"
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addButton)

        // Tabs-count button — bordered square showing how many tabs are open. Placed after +.
        tabsButton.setTitle("1", for: .normal)
        tabsButton.setTitleColor(.darkGray, for: .normal)
        tabsButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        tabsButton.layer.borderColor = UIColor.darkGray.cgColor
        tabsButton.layer.borderWidth = 1.5
        tabsButton.layer.cornerRadius = 4
        tabsButton.accessibilityLabel = "Tabs"
        tabsButton.addTarget(self, action: #selector(tabsButtonTapped), for: .touchUpInside)
        tabsButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tabsButton)

        NSLayoutConstraint.activate([
            // Leading inset keeps the first tab away from the iPad's rounded corner.
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.trailingAnchor.constraint(equalTo: addButton.leadingAnchor),

            addButton.trailingAnchor.constraint(equalTo: tabsButton.leadingAnchor, constant: -6),
            addButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 32),
            addButton.heightAnchor.constraint(equalToConstant: 32),

            // Trailing inset keeps the tabs button away from the iPad's rounded corner.
            tabsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            tabsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            tabsButton.widthAnchor.constraint(equalToConstant: 26),
            tabsButton.heightAnchor.constraint(equalToConstant: 26),
        ])

        // Long-press to drag a tab and reorder it using our own gesture.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleReorderLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private weak var dragCell: UICollectionViewCell?

    @objc private func handleReorderLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: collectionView)
        switch gesture.state {
        case .began:
            guard let indexPath = collectionView.indexPathForItem(at: location) else { return }
            collectionView.beginInteractiveMovementForItem(at: indexPath)
            // Firefox-style lift: scale up + shadow so the dragged tab visually "lifts off".
            if let cell = collectionView.cellForItem(at: indexPath) {
                dragCell = cell
                UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut) {
                    cell.transform = CGAffineTransform(scaleX: 1.08, y: 1.1)
                    cell.layer.shadowColor = UIColor.black.cgColor
                    cell.layer.shadowOpacity = 0.35
                    cell.layer.shadowRadius = 8
                    cell.layer.shadowOffset = CGSize(width: 0, height: 4)
                    cell.layer.masksToBounds = false
                }
            }
        case .changed:
            collectionView.updateInteractiveMovementTargetPosition(location)
        case .ended:
            collectionView.endInteractiveMovement()
            lowerDragCell()
        default:
            collectionView.cancelInteractiveMovement()
            lowerDragCell()
        }
    }

    private func lowerDragCell() {
        guard let cell = dragCell else { return }
        dragCell = nil
        UIView.animate(withDuration: 0.15) {
            cell.transform = .identity
            cell.layer.shadowOpacity = 0
        }
    }

    /// Update the displayed tabs + highlight; call whenever tabs change or a title/favicon updates.
    func update(tabs: [Tab], selectedTab: Tab?) {
        self.tabs = tabs
        self.selectedTab = selectedTab
        collectionView.reloadData()
    }

    @objc private func addTapped() { onNewTab?() }
    @objc private func tabsButtonTapped() { onTabsButtonTapped?() }

    func setTabCount(_ count: Int) {
        tabsButton.setTitle("\(count)", for: .normal)
        tabsButton.accessibilityLabel = "Tabs, \(count) open"
    }

    // MARK: Collection view

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "stripCell", for: indexPath) as! TabStripCell
        let tab = tabs[indexPath.item]
        let titleText = (tab.title?.isEmpty == false) ? tab.title : (tab.urlString ?? "New Tab")
        cell.configure(title: titleText, favicon: tab.favicon, isSelected: tab === selectedTab)
        cell.onClose = { [weak self] in self?.onCloseTab?(tab) }   // capture tab, not indexPath
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelectTab?(tabs[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let tab = tabs.remove(at: sourceIndexPath.item)
        tabs.insert(tab, at: destinationIndexPath.item)
        onReorderTab?(sourceIndexPath.item, destinationIndexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 168, height: max(0, collectionView.bounds.height - 12))
    }
}

/// One compact tab in the strip: favicon + truncated title + close (✕). Highlighted when active.
final class TabStripCell: UICollectionViewCell {

    private let favicon = UIImageView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    var onClose: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true

        favicon.contentMode = .scaleAspectFit
        favicon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(favicon)

        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .gray
        closeButton.accessibilityLabel = "Close tab"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            favicon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            favicon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            favicon.widthAnchor.constraint(equalToConstant: 16),
            favicon.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: favicon.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            closeButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func configure(title: String?, favicon image: UIImage?, isSelected: Bool) {
        titleLabel.text = title
        favicon.image = image ?? UIImage(systemName: "globe")
        if image == nil { favicon.tintColor = .gray }
        contentView.backgroundColor = isSelected ? Constant.activeTabColor() : Constant.inactiveTabColor()
        titleLabel.textColor = isSelected ? .black : UIColor(white: 0.35, alpha: 1.0)
        titleLabel.font = isSelected ? .systemFont(ofSize: 13, weight: .semibold) : .systemFont(ofSize: 13)
    }

    @objc private func closeTapped() { onClose?() }

    override func prepareForReuse() {
        super.prepareForReuse()
        favicon.image = nil
        onClose = nil
    }
}

/// Simple modal tab list opened by the tabs button (useful when there are many tabs): one row per
/// tab (favicon + page name + ✕), tap to switch, + to add, Done to dismiss.
final class TabListViewController: UITableViewController {

    var tabs: [Tab] = []
    var selectedTab: Tab?

    var onSelectTab: ((Tab) -> Void)?
    var onCloseTab: ((Tab) -> Void)?
    var onNewTab: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tabs"
        overrideUserInterfaceStyle = .light
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(newTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
    }

    @objc private func newTapped() { dismiss(animated: true) { [weak self] in self?.onNewTab?() } }
    @objc private func doneTapped() { dismiss(animated: true) }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tabs.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tabRow")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "tabRow")
        let tab = tabs[indexPath.row]
        cell.textLabel?.text = (tab.title?.isEmpty == false) ? tab.title : (tab.urlString ?? "New Tab")
        cell.textLabel?.textColor = .black
        cell.detailTextLabel?.text = tab.urlString
        cell.detailTextLabel?.textColor = .gray
        // Normalise all favicons to the same display size so large app-icons don't dwarf small ones.
        let iconSize = CGSize(width: 28, height: 28)
        if let favicon = tab.favicon {
            cell.imageView?.image = favicon.resized(to: iconSize)
        } else {
            cell.imageView?.image = UIImage(systemName: "globe",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16))
        }
        cell.imageView?.tintColor = .gray
        cell.backgroundColor = (tab === selectedTab) ? UIColor(white: 0.92, alpha: 1.0) : .white

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .gray
        closeButton.accessibilityLabel = "Close tab"
        closeButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        closeButton.addTarget(self, action: #selector(closeButtonTapped(_:)), for: .touchUpInside)
        cell.accessoryView = closeButton
        return cell
    }

    @objc private func closeButtonTapped(_ sender: UIButton) {
        let point = sender.convert(CGPoint.zero, to: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        let tab = tabs[indexPath.row]
        tabs.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        onCloseTab?(tab)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let tab = tabs[indexPath.row]
        dismiss(animated: true) { [weak self] in self?.onSelectTab?(tab) }
    }
}


private extension UIImage {
    /// Returns a copy of the image scaled to `size`, used to normalise favicon sizes in table cells.
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
