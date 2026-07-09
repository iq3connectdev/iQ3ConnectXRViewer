import FontAwesomeKit
import UIKit
import CocoaLumberjack

let URL_FIELD_HEIGHT = 29

class BarView: UIView, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Properties & Outlets

    @objc var backActionBlock: ((Any?) -> Void)?
    @objc var forwardActionBlock: ((Any?) -> Void)?
    @objc var homeActionBlock: ((Any?) -> Void)?
    @objc var reloadActionBlock: ((Any?) -> Void)?
    @objc var cancelActionBlock: ((Any?) -> Void)?
    @objc var showPermissionsActionBlock: ((Any?) -> Void)?
    @objc var goActionBlock: ((String?) -> Void)?
    @objc var debugButtonToggledAction: ((Bool) -> Void)?
    @objc var settingsActionBlock: (() -> Void)?
    @objc var restartTrackingActionBlock: (() -> Void)?
    @objc var switchCameraActionBlock: (() -> Void)?
    @objc var suggestionSelectedBlock: ((String?) -> Void)?
    @objc var qrScanActionBlock: (() -> Void)?
    @objc var bookmarkToggleActionBlock: (() -> Void)?
    @objc var bookmarksListActionBlock: (() -> Void)?
    @objc var tabsActionBlock: (() -> Void)?

    // Address-bar autocomplete dropdown
    private var suggestionsTableView: UITableView?
    private var suggestions: [Suggestion] = []
    private let suggestionRowHeight: CGFloat = 52
    private let maxVisibleSuggestions = 6
    private static let toolbarSymbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
    /// Bookmark is a narrow symbol by design; slightly larger + medium weight brings its visual weight in line.
    private static let bookmarkSymbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
    private var progressView: UIProgressView?

    @IBOutlet weak var urlField: URLTextField!
    @IBOutlet private weak var backBtn: UIButton!
    @IBOutlet private weak var forwardBtn: UIButton!
    @IBOutlet private weak var homeBtn: UIButton!
//    @IBOutlet private weak var debugBtn: UIButton!
    @IBOutlet private weak var settingsBtn: UIButton!
    private weak var reloadBtn: UIButton?
    private weak var cancelBtn: UIButton?
    private weak var qrButton: UIButton?
    private weak var bookmarkButton: UIButton?
    private weak var bookmarksListButton: UIButton?
    private weak var tabsButton: UIButton?
    private weak var overflowButton: UIButton?
    private var currentPageBookmarked = false
    /// iPad has room for a dedicated bookmark button in the bar; iPhone moves it into the ••• menu.
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    weak var permissionLevelButton: ActivityIndicatorButton?
//    @IBOutlet private weak var restartTrackingBtn: UIButton!
    @IBOutlet private weak var switchCameraBtn: UIButton!

    // MARK: - View Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()

        setup()
    }

    func setup() {
        backBtn.setImage(UIImage(systemName: "chevron.left", withConfiguration: BarView.toolbarSymbolConfig), for: .normal)
        forwardBtn.setImage(UIImage(systemName: "chevron.right", withConfiguration: BarView.toolbarSymbolConfig), for: .normal)
        // Unify bar background with tab strip via the shared chrome palette.
        if let backView = subviews.first(where: { String(describing: type(of: $0)) == "__UIGroupedView" || !($0 is UIStackView) }) {
            backView.backgroundColor = Constant.chromeBackgroundColor()
        }
        // Fallback: tint the bar itself to match (handles both XIB-loaded and future layouts).
        backgroundColor = Constant.chromeBackgroundColor()

        backBtn.tintColor = .darkGray
        forwardBtn.tintColor = .darkGray
        backBtn.accessibilityLabel = "Back"
        forwardBtn.accessibilityLabel = "Forward"
        backBtn.isEnabled = false
        forwardBtn.isEnabled = false

        urlField.delegate = self
        urlField.addTarget(self, action: #selector(urlFieldEditingChanged(_:)), for: .editingChanged)

        let permissionButton = ActivityIndicatorButton(type: .custom)
        permissionButton.setImage(nil, for: .normal)
        permissionButton.addTarget(self, action: #selector(BarView.showPermissionsAction(_:)), for: .touchUpInside)
        permissionButton.frame = CGRect(x: 0, y: 0, width: CGFloat(URL_FIELD_HEIGHT), height: CGFloat(URL_FIELD_HEIGHT))
        permissionButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        permissionButton.isEnabled = false
        urlField.leftView = permissionButton
        urlField.leftViewMode = .never   // hidden until setSecurityState sets it appropriately
        permissionLevelButton = permissionButton

        urlField.clearButtonMode = .whileEditing
        urlField.returnKeyType = .go

        urlField.textContentType = .URL
        urlField.placeholder = "Search or Enter web address"
        urlField.attributedPlaceholder = NSAttributedString(
            string: "Search or Enter web address",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor(white: 0.0, alpha: 0.5)]
        )
        urlField.layer.cornerRadius = CGFloat(URL_FIELD_HEIGHT / 4)
        urlField.textAlignment = .left
        urlField.textColor = UIColor.black
        urlField.font = .systemFont(ofSize: 15)

        let reloadButton = UIButton(type: .system)
        reloadButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        reloadButton.tintColor = .darkGray
        reloadButton.accessibilityLabel = "Reload"
        reloadButton.addTarget(self, action: #selector(BarView.reloadAction(_:)), for: .touchUpInside)
        reloadButton.frame = CGRect(x: 0, y: 0, width: CGFloat(URL_FIELD_HEIGHT), height: CGFloat(URL_FIELD_HEIGHT))
        reloadButton.isHidden = false

        let cancelButton = UIButton(type: .system)
        cancelButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        cancelButton.tintColor = .darkGray
        cancelButton.accessibilityLabel = "Stop loading"
        cancelButton.addTarget(self, action: #selector(BarView.cancelAction(_:)), for: .touchUpInside)
        cancelButton.frame = CGRect(x: 0, y: 0, width: CGFloat(URL_FIELD_HEIGHT), height: CGFloat(URL_FIELD_HEIGHT))
        cancelButton.isHidden = true

        let rightView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(URL_FIELD_HEIGHT), height: CGFloat(URL_FIELD_HEIGHT)))
        rightView.addSubview(reloadButton)
        rightView.addSubview(cancelButton)
        self.cancelBtn = cancelButton
        self.reloadBtn = reloadButton

        urlField.rightView = rightView
        urlField.rightViewMode = .unlessEditing

        // De-clutter: move Home / Bookmarks / Settings into a single "•••" overflow menu.
        homeBtn?.removeFromSuperview()
        settingsBtn?.removeFromSuperview()

        // QR is always visible. On iPad the bookmark star also stays in the bar; on iPhone it moves
        // into the "•••" overflow menu to de-clutter the narrow row.
        if let stack = urlField.superview as? UIStackView,
           let baseIndex = stack.arrangedSubviews.firstIndex(of: urlField) {
            var insertAt = baseIndex + 1

            let qrButton = makeToolbarButton(systemName: "qrcode.viewfinder", action: #selector(qrScanAction))
            qrButton.accessibilityLabel = "Scan QR code"
            stack.insertArrangedSubview(qrButton, at: insertAt); insertAt += 1
            self.qrButton = qrButton

            if isPad {
                let bookmarkButton = makeToolbarButton(systemName: "bookmark", action: #selector(bookmarkToggleAction), config: BarView.bookmarkSymbolConfig)
                bookmarkButton.accessibilityLabel = "Add bookmark"
                stack.insertArrangedSubview(bookmarkButton, at: insertAt); insertAt += 1
                self.bookmarkButton = bookmarkButton
            }

            stack.addArrangedSubview(makeOverflowButton())
        }

//        debugBtn.setImage(UIImage(named: "debugOff"), for: .normal)
//        debugBtn.setImage(UIImage(named: "debugOn"), for: .selected)

        var error: Error?
        let streetViewIcon = try? FAKFontAwesome.init(identifier: "fa-street-view", size: 24)
        if error != nil {
            print("\(error?.localizedDescription ?? "")")
        } else {
            let streetViewImage: UIImage? = streetViewIcon?.image(with: CGSize(width: 24, height: 24))
//            restartTrackingBtn.setImage(streetViewImage, for: .normal)
//            restartTrackingBtn.tintColor = UIColor.gray
        }

        // Thin page-load progress bar pinned to the bottom edge of the bar (the web-content seam).
        let progress = UIProgressView(progressViewStyle: .bar)
        progress.trackTintColor = .clear
        progress.progressTintColor = .systemBlue
        progress.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progress)
        NSLayoutConstraint.activate([
            progress.leadingAnchor.constraint(equalTo: leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: trailingAnchor),
            progress.bottomAnchor.constraint(equalTo: bottomAnchor),
            progress.heightAnchor.constraint(equalToConstant: 2.5),
        ])
        progress.alpha = 0
        self.progressView = progress
    }

    // MARK: - Helpers
    
    @objc func urlFieldText() -> String? {
        return urlField.text
    }
    
    // MARK: - Actions
    
    @objc func startLoading(_ url: String?) {
        urlField.leftViewMode = .never
        cancelBtn?.isHidden = false
        reloadBtn?.isHidden = true
        urlField.text = url
        progressView?.alpha = 1
        progressView?.setProgress(0.05, animated: false)
    }

    @objc func finishLoading(_ url: String?) {
        cancelBtn?.isHidden = true
        reloadBtn?.isHidden = false
        finishLoadProgress()
    }

    /// Drive the page-load progress bar (0...1). Called as estimatedProgress changes.
    @objc func setLoadProgress(_ progress: Float) {
        guard let bar = progressView else { return }
        if progress <= 0 {
            bar.setProgress(0, animated: false)
        } else {
            bar.alpha = 1
            bar.setProgress(progress, animated: true)
        }
    }

    /// Fill to 100% then fade the progress bar out.
    @objc func finishLoadProgress() {
        guard let bar = progressView else { return }
        bar.setProgress(1.0, animated: true)
        UIView.animate(withDuration: 0.25, delay: 0.2, options: [], animations: {
            bar.alpha = 0
        }, completion: { _ in
            bar.setProgress(0, animated: false)
        })
    }
    
    @objc func setBackEnabled(_ enabled: Bool) {
        backBtn.isEnabled = enabled
    }
    
    @objc func setForwardEnabled(_ enabled: Bool) {
        forwardBtn.isEnabled = enabled
    }
    
    @objc func setSwitchCameraVisible(_ visible: Bool) {
        if switchCameraBtn != nil {
            switchCameraBtn.isHidden = !visible
        }
    }

    /// Disable the QR-scan button while ARKit owns the camera (i.e. during an AR session).
    @objc func setQRScanEnabled(_ enabled: Bool) {
        qrButton?.isEnabled = enabled
        qrButton?.alpha = enabled ? 1.0 : 0.4
    }

    /// Reflect whether the current page is bookmarked: the bar's star button on iPad, or the
    /// overflow menu's bookmark item on iPhone.
    @objc func setBookmarked(_ bookmarked: Bool) {
        currentPageBookmarked = bookmarked
        if isPad {
            let imageName = bookmarked ? "bookmark.fill" : "bookmark"
            bookmarkButton?.setImage(UIImage(systemName: imageName, withConfiguration: BarView.bookmarkSymbolConfig), for: .normal)
            bookmarkButton?.tintColor = bookmarked ? .systemBlue : .darkGray
            bookmarkButton?.accessibilityLabel = bookmarked ? "Remove bookmark" : "Add bookmark"
        } else {
            updateOverflowMenu()
        }
    }

    private func makeToolbarButton(systemName: String, action: Selector,
                                   config: UIImage.SymbolConfiguration? = nil) -> UIButton {
        let button = UIButton(type: .system)
        let cfg = config ?? BarView.toolbarSymbolConfig
        button.setImage(UIImage(systemName: systemName, withConfiguration: cfg), for: .normal)
        button.tintColor = .darkGray
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return button
    }

    /// The "•••" overflow button. Its menu holds the less-frequent actions: add/remove bookmark,
    /// bookmarks list, home, settings.
    private func makeOverflowButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis", withConfiguration: BarView.toolbarSymbolConfig), for: .normal)
        button.tintColor = .darkGray
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.accessibilityLabel = "More"
        button.showsMenuAsPrimaryAction = true
        button.overrideUserInterfaceStyle = .light
        self.overflowButton = button
        updateOverflowMenu()
        return button
    }

    /// Rebuild the overflow menu (called on creation and whenever the page's bookmark state changes).
    /// On iPhone it includes an add/remove-bookmark item; on iPad that lives in the bar's star button.
    private func updateOverflowMenu() {
        var actions: [UIMenuElement] = []
        if !isPad {
            actions.append(UIAction(title: currentPageBookmarked ? "Remove Bookmark" : "Add Bookmark",
                                    image: UIImage(systemName: currentPageBookmarked ? "bookmark.fill" : "bookmark")) { [weak self] _ in
                self?.bookmarkToggleActionBlock?()
            })
        }
        actions.append(UIAction(title: "Bookmarks", image: UIImage(systemName: "list.bullet")) { [weak self] _ in self?.bookmarksListActionBlock?() })
        actions.append(UIAction(title: "Home", image: UIImage(systemName: "house")) { [weak self] _ in self?.homeActionBlock?(nil) })
        actions.append(UIAction(title: "Settings", image: UIImage(systemName: "gearshape")) { [weak self] _ in self?.settingsActionBlock?() })
        overflowButton?.menu = UIMenu(children: actions)
    }

    /// A bordered square button showing the open-tab count (classic mobile-browser tab button).
    private func makeTabsButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("1", for: .normal)
        button.setTitleColor(.darkGray, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        button.layer.borderColor = UIColor.darkGray.cgColor
        button.layer.borderWidth = 1.5
        button.layer.cornerRadius = 4
        button.addTarget(self, action: #selector(tabsAction), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return button
    }

    /// Update the number shown inside the tabs button.
    @objc func setTabCount(_ count: Int) {
        tabsButton?.setTitle("\(count)", for: .normal)
        tabsButton?.accessibilityLabel = "Tabs, \(count) open"
    }
    
//    func setDebugSelected(_ selected: Bool) {
//        debugBtn.isSelected = selected
//    }
//
//    @objc func setDebugVisible(_ visible: Bool) {
//        debugBtn.isHidden = !visible
//    }
//
//    @objc func setRestartTrackingVisible(_ visible: Bool) {
//        restartTrackingBtn.isHidden = !visible
//    }
    
    @objc func hideKeyboard() {
        urlField.resignFirstResponder()
        hideSuggestions()
    }
    
//    @objc func isDebugButtonSelected() -> Bool {
//        return debugBtn.isSelected
//    }
    
    @objc func hideCameraFlipButton() {
        switchCameraBtn.removeFromSuperview()
    }
    
    // MARK: - Button Actions
    
    @IBAction func backAction(_ sender: Any) {
        DDLogDebug("backAction")
        urlField.resignFirstResponder()
        backActionBlock?(sender)
    }

    @IBAction func forwardAction(_ sender: Any) {
        DDLogDebug("forwardAction")
        urlField.resignFirstResponder()
        forwardActionBlock?(sender)
    }

    @IBAction func homeAction(_ sender: Any) {
        DDLogDebug("homeAction")
        homeActionBlock?(sender)
    }

    @IBAction func reloadAction(_ sender: Any) {
        DDLogDebug("reloadAction")
        urlField.resignFirstResponder()
        reloadActionBlock?(sender)
    }

    @IBAction func cancelAction(_ sender: Any) {
        DDLogDebug("cancelAction")
        urlField.resignFirstResponder()
        cancelActionBlock?(sender)
    }
    
    @IBAction func showPermissionsAction(_ sender: Any) {
        DDLogDebug("showPermissionsAction")
        urlField.resignFirstResponder()
        showPermissionsActionBlock?(sender)
    }

//    @IBAction func debugAction(_ sender: Any) {
//        debugBtn.isSelected = !debugBtn.isSelected
//        debugButtonToggledAction?(debugBtn.isSelected)
//    }

    @IBAction func settingsAction() {
        settingsActionBlock?()
    }

    @objc func qrScanAction() {
        urlField.resignFirstResponder()
        hideSuggestions()
        qrScanActionBlock?()
    }

    @objc func bookmarkToggleAction() {
        urlField.resignFirstResponder()
        hideSuggestions()
        bookmarkToggleActionBlock?()
    }

    @objc func bookmarksListAction() {
        urlField.resignFirstResponder()
        hideSuggestions()
        bookmarksListActionBlock?()
    }

    @objc func tabsAction() {
        urlField.resignFirstResponder()
        hideSuggestions()
        tabsActionBlock?()
    }

    @IBAction func restartTrackingAction(_ sender: Any) {
        restartTrackingActionBlock?()
    }

    @IBAction func switchCameraAction(_ sender: Any) {
        switchCameraActionBlock?()
    }

    @objc private func urlFieldEditingChanged(_ sender: UITextField) {
        let query = sender.text ?? ""
        suggestions = BrowserDataStore.shared.suggestions(for: query, limit: maxVisibleSuggestions)
        if suggestions.isEmpty {
            hideSuggestions()
        } else {
            showSuggestions()
        }
    }

    private func showSuggestions() {
        guard let host = superview else { return }

        let table: UITableView
        if let existing = suggestionsTableView {
            table = existing
        } else {
            table = UITableView(frame: .zero, style: .plain)
            table.dataSource = self
            table.delegate = self
            table.rowHeight = suggestionRowHeight
            table.backgroundColor = .white
            table.layer.cornerRadius = 8
            table.layer.borderWidth = 0.5
            table.layer.borderColor = UIColor(white: 0.8, alpha: 1.0).cgColor
            table.clipsToBounds = true
            // Keep the dropdown white even when the device is in Dark Mode (default cell
            // colors would otherwise render dark on a dark-themed device).
            table.overrideUserInterfaceStyle = .light
            host.addSubview(table)
            suggestionsTableView = table
        }

        // Sit the dropdown directly under the URL field, matching its width.
        let fieldFrame = urlField.convert(urlField.bounds, to: host)
        let visible = min(suggestions.count, maxVisibleSuggestions)
        let height = CGFloat(visible) * suggestionRowHeight
        table.frame = CGRect(x: fieldFrame.minX, y: fieldFrame.maxY + 2,
                             width: fieldFrame.width, height: height)
        table.isHidden = false
        host.bringSubviewToFront(table)
        host.bringSubviewToFront(self) // keep the bar itself above the dropdown's top edge
        table.reloadData()
    }

    @objc func hideSuggestions() {
        suggestionsTableView?.isHidden = true
        suggestions = []
    }


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return suggestions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "suggestionCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "suggestionCell")

        let suggestion = suggestions[indexPath.row]
        // Pin every color explicitly so the dropdown never follows the system light/dark
        // appearance (default cells would otherwise render dark on a dark-themed device).
        cell.backgroundColor = .white
        cell.contentView.backgroundColor = .white
        cell.textLabel?.textColor = .black
        cell.detailTextLabel?.textColor = .gray
        cell.imageView?.tintColor = .gray

        switch suggestion.kind {
        case .search:
            cell.textLabel?.text = suggestion.primaryText
            cell.detailTextLabel?.text = "Search"
            cell.imageView?.image = UIImage(systemName: "magnifyingglass")
        case .history:
            cell.textLabel?.text = suggestion.secondaryText.isEmpty ? suggestion.primaryText : suggestion.secondaryText
            cell.detailTextLabel?.text = suggestion.primaryText
            cell.imageView?.image = UIImage(systemName: "clock")
        case .bookmark:
            cell.textLabel?.text = suggestion.secondaryText.isEmpty ? suggestion.primaryText : suggestion.secondaryText
            cell.detailTextLabel?.text = suggestion.primaryText
            cell.imageView?.image = UIImage(systemName: "bookmark")
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let suggestion = suggestions[indexPath.row]
        urlField.text = suggestion.primaryText
        urlField.resignFirstResponder()
        hideSuggestions()
        suggestionSelectedBlock?(suggestion.primaryText)
    }

    // MARK: - UITextField Delegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        hideSuggestions()
        goActionBlock?(textField.text)
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        DispatchQueue.main.async {
            textField.selectAll(nil)
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        hideSuggestions()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let minXPos = backBtn.frame.maxX
        let maxXPos = forwardBtn.frame.minX

        let increaseValue: CGFloat = (maxXPos - minXPos) / 2

        let icreasedBackRect = CGRect(x: backBtn.frame.origin.x - increaseValue, y: backBtn.frame.origin.y - increaseValue, width: backBtn.frame.size.width + increaseValue * 2, height: backBtn.frame.size.height + increaseValue * 2)

        let icreasedForwardRect = CGRect(x: forwardBtn.frame.origin.x - increaseValue, y: forwardBtn.frame.origin.y - increaseValue, width: forwardBtn.frame.size.width + increaseValue * 2, height: forwardBtn.frame.size.height + increaseValue * 2)

        if icreasedBackRect.contains(point) {
            return backBtn
        }

        if icreasedForwardRect.contains(point) {
            return forwardBtn
        }

        return super.hitTest(point, with: event)
    }
}

class URLTextField: UITextField {
    private let textPadding = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

    override func leftViewRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(x: 0, y: 0, width: CGFloat(URL_FIELD_HEIGHT), height: CGFloat(URL_FIELD_HEIGHT))
    }
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return super.textRect(forBounds: bounds).inset(by: textPadding)
    }
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return super.editingRect(forBounds: bounds).inset(by: textPadding)
    }
}
