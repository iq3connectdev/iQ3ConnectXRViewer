import UIKit
//import PopupDialog
//import CocoaLumberjack

enum ResetTrackingOption {
    case resetTracking
    case removeExistingAnchors
    case saveWorldMap
    case loadSavedWorldMap
}

class MessageController: NSObject, UITableViewDelegate, UITableViewDataSource {
    
    @objc var didShowMessage: (() -> Void)?
    @objc var didHideMessage: (() -> Void)?
    @objc var didHideMessageByUser: (() -> Void)?
    private weak var viewController: UIViewController?
    var requestXRPermissionsVC: RequestXRPermissionsViewController?
    private var webXRAuthorizationRequested: WebXRAuthorizationState = .notDetermined
    private var site: String?
    var permissionsPopup: UIAlertController?
    var forceShowPermissionsPopup = false

    @objc init(viewController vc: UIViewController?) {
        super.init()
        
        viewController = vc
//        setupAppearance()
    }
    
    deinit {
        DDLogDebug("MessageController dealloc")
    }
    
    @objc func clean() {
        hideMessages()
    }
    
    func arMessageShowing() -> Bool {
        return viewController?.presentedViewController != nil
    }
    
    @objc func hideMessages() {
        viewController?.presentedViewController?.dismiss(animated: true)
    }

    @objc func showMessageAboutWebError(_ error: Error?, withCompletion reloadCompletion: @escaping (_ reload: Bool) -> Void) {
        weak var blockSelf: MessageController? = self
        
        let alertController = UIAlertController(
            title: "Cannot Open the Page",
            message: "Please check the URL and try again",
            preferredStyle: .alert
        )

        let cancelAction = UIAlertAction(title: "Ok", style: .cancel) { _ in
            reloadCompletion(false)
            blockSelf?.didHideMessageByUser?()
        }

        let okAction = UIAlertAction(title: "Reload", style: .default) { _ in
            reloadCompletion(true)
            blockSelf?.didHideMessageByUser?()
        }

        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        
        viewController?.present(alertController, animated: true)
        didShowMessage?()
    }

    @objc func showMessageAboutARInterruption(_ interrupt: Bool) {
        if interrupt {
            let alertController = UIAlertController(
                title: "AR Interruption Occurred",
                message: "Please wait, it should be fixed automatically",
                preferredStyle: .alert
            )

            viewController?.present(alertController, animated: true)
            didShowMessage?()
        } else if viewController?.presentedViewController is UIAlertController {
            viewController?.presentedViewController?.dismiss(animated: true)
            didHideMessage?()
        }
    }

    @objc func showMessageAboutFailSession(withMessage message: String?, completion: @escaping () -> Void) {
        weak var blockSelf: MessageController? = self
        
        let alertController = UIAlertController(
            title: "AR Session Failed",
            message: message,
            preferredStyle: .alert
        )

        let okAction = UIAlertAction(title: "Ok", style: .default) { _ in
            blockSelf?.didHideMessageByUser?()
            completion()
        }

        alertController.addAction(okAction)
        viewController?.present(alertController, animated: true)
        didShowMessage?()
    }

    @objc func showMessage(withTitle title: String?, message: String?, hideAfter seconds: Int) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        viewController?.present(alertController, animated: true)

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(seconds * Int(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: {
            alertController.dismiss(animated: true)
        })
    }

    @objc func showMessageAboutMemoryWarning(withCompletion completion: @escaping () -> Void) {
        weak var blockSelf: MessageController? = self
        
        let alertController = UIAlertController(
            title: "Memory Issue Occurred",
            message: "There was not enough memory for the application to keep working",
            preferredStyle: .alert
        )

        let okAction = UIAlertAction(title: "Ok", style: .default) { _ in
            completion()
            blockSelf?.didHideMessageByUser?()
        }

        alertController.addAction(okAction)
        viewController?.present(alertController, animated: true)
        didShowMessage?()
    }

    @objc func showMessageAboutConnectionRequired() {
        weak var blockSelf: MessageController? = self
        
        let alertController = UIAlertController(
            title: "Internet Connection is Unavailable",
            message: "Application will restart automatically when a connection becomes available",
            preferredStyle: .alert
        )

        let okAction = UIAlertAction(title: "Ok", style: .default) { _ in
            blockSelf?.didHideMessageByUser?()
        }

        alertController.addAction(okAction)
        viewController?.present(alertController, animated: true)
        didShowMessage?()
    }

    func showMessageAboutResetTracking(_ responseBlock: @escaping (ResetTrackingOption) -> Void) {
        let alertController = UIAlertController(
            title: "Reset Tracking",
            message: "Please select one of the options below",
            preferredStyle: .actionSheet
        )

        let resetTrackingAction = UIAlertAction(title: "Completely restart tracking", style: .default) { _ in
            responseBlock(.resetTracking)
        }

        let removeExistingAnchorsAction = UIAlertAction(title: "Remove known anchors", style: .default) { _ in
            responseBlock(.removeExistingAnchors)
        }

        let saveWorldMapAction = UIAlertAction(title: "Save World Map", style: .default) { _ in
            responseBlock(.saveWorldMap)
        }

        let loadWorldMapAction = UIAlertAction(title: "Load previously saved World Map", style: .default) { _ in
            responseBlock(.loadSavedWorldMap)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alertController.addAction(resetTrackingAction)
        alertController.addAction(removeExistingAnchorsAction)
        alertController.addAction(saveWorldMapAction)
        alertController.addAction(loadWorldMapAction)
        alertController.addAction(cancelAction)

        viewController?.present(alertController, animated: true)
    }

    @objc func showMessageAboutAccessingTheCapturedImage(_ granted: @escaping (Bool) -> Void) {
        let alertController = UIAlertController(
            title: "Video Camera Image Access",
            message: "WebXR Viewer displays video from your camera without giving the web page access to the video.\n\nThis page is requesting access to images from the video camera. Allow?",
            preferredStyle: .alert
        )

        let yesAction = UIAlertAction(title: "YES", style: .default) { _ in
            granted(true)
        }

        let noAction = UIAlertAction(title: "NO", style: .cancel) { _ in
            granted(false)
        }

        alertController.addAction(noAction)
        alertController.addAction(yesAction)
        viewController?.present(alertController, animated: true)
    }

    @objc func showPermissionsPopup() {
        let permissionsViewController = RequestPermissionsViewController()
        
        // Create a container for the custom view controller
        let alertController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .alert
        )
        
        // Add the permissions view to the alert controller
        alertController.view.addSubview(permissionsViewController.view)
        permissionsViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Set constraints
        NSLayoutConstraint.activate([
            permissionsViewController.view.topAnchor.constraint(equalTo: alertController.view.topAnchor),
            permissionsViewController.view.bottomAnchor.constraint(equalTo: alertController.view.bottomAnchor),
            permissionsViewController.view.leadingAnchor.constraint(equalTo: alertController.view.leadingAnchor),
            permissionsViewController.view.trailingAnchor.constraint(equalTo: alertController.view.trailingAnchor),
            permissionsViewController.view.heightAnchor.constraint(equalToConstant: 300.0)
        ])
        
        // Configure alert controller
        alertController.preferredContentSize = CGSize(width: 340, height: 300)
        
        // Add a done button
        let doneAction = UIAlertAction(title: "Done", style: .cancel, handler: nil)
        alertController.addAction(doneAction)
        
        viewController?.present(alertController, animated: true)
    }
    
    @objc func showMessageAboutEnteringXR(_ authorizationRequested: WebXRAuthorizationState, authorizationGranted: @escaping (WebXRAuthorizationState) -> Void, url: URL) {
        weak var blockSelf: MessageController? = self
        let standardUserDefaults = UserDefaults.standard
        let allowedMinimalSites = standardUserDefaults.dictionary(forKey: Constant.allowedMinimalSitesKey())
        let allowedWorldSensingSites = standardUserDefaults.dictionary(forKey: Constant.allowedWorldSensingSitesKey())
        let allowedVideoCameraSites = standardUserDefaults.dictionary(forKey: Constant.allowedVideoCameraSitesKey())
        guard var currentSite: String = url.host else { return }
        webXRAuthorizationRequested = authorizationRequested
        
        if let port = url.port {
            currentSite = currentSite + ":\(port)"
        }
        site = currentSite
        
        if !forceShowPermissionsPopup {
            
            switch authorizationRequested {
            case .minimal:
                standardUserDefaults.set(true, forKey: Constant.minimalWebXREnabled())
                if allowedMinimalSites?[currentSite] != nil {
                    authorizationGranted(.minimal)
                    return
                }
            case .worldSensing:
                standardUserDefaults.set(true, forKey: Constant.minimalWebXREnabled())
                standardUserDefaults.set(true, forKey: Constant.worldSensingWebXREnabled())
                if standardUserDefaults.bool(forKey: Constant.alwaysAllowWorldSensingKey())
                    || allowedWorldSensingSites?[currentSite] != nil
                {
                    authorizationGranted(.worldSensing)
                    return
                }
            case .videoCameraAccess:
                standardUserDefaults.set(true, forKey: Constant.minimalWebXREnabled())
                standardUserDefaults.set(true, forKey: Constant.worldSensingWebXREnabled())
                standardUserDefaults.set(true, forKey: Constant.videoCameraAccessWebXREnabled())
                if allowedVideoCameraSites?[currentSite] != nil {
                    authorizationGranted(.videoCameraAccess)
                    return
                }
            default:
                break
            }
        }
        
        // Create a custom XR permissions view controller
        requestXRPermissionsVC = RequestXRPermissionsViewController()
        guard let requestXRPermissionsVC = requestXRPermissionsVC else { return }
        
        // Configure the table view
        var height = CGFloat()
        let rowHeight: CGFloat = 44
        switch webXRAuthorizationRequested {
        case .minimal:
            height = rowHeight * 3
        case .lite:
            height = rowHeight * 3
        case .worldSensing:
            height = rowHeight * 4
        case .videoCameraAccess:
            height = rowHeight * 5
        default:
            height = rowHeight * 1
        }
        
        requestXRPermissionsVC.tableView.heightAnchor.constraint(equalToConstant: height).isActive = true
        requestXRPermissionsVC.tableView.isScrollEnabled = false
        requestXRPermissionsVC.tableView.delegate = self
        requestXRPermissionsVC.tableView.dataSource = self
        requestXRPermissionsVC.tableView.register(UINib(nibName: "SwitchInputTableViewCell", bundle: Bundle.main), forCellReuseIdentifier: "SwitchInputTableViewCell")
        requestXRPermissionsVC.tableView.register(UINib(nibName: "SegmentedControlTableViewCell", bundle: Bundle.main), forCellReuseIdentifier: "SegmentedControlTableViewCell")
        
        // Set title and message based on authorization requested
        var title: String
        var message: String
        switch webXRAuthorizationRequested {
        case .minimal:
            title = "Allow usage of Device Motion?"
            message = "WebXR displays video from your camera without giving this web page access to the video."
        case .lite:
            title = "Allow Lite Mode?"
            message = """
                Lite Mode:
                -Uses a single real world plane
                -Looks for faces
            """
        case .worldSensing:
            title = "Allow World Sensing?"
            message = """
                World Sensing:
                -Uses real world planes & lighting
                -Looks for faces & images
            """
        case .videoCameraAccess:
            title = "Allow Video Camera Access?"
            message = """
                Video Camera Access:
                -Accesses your camera's live image
                -Uses real world planes & lighting
                -Looks for faces & images
            """
        default:
            title = "This site is not requesting WebXR authorization"
            message = "No video from your camera, planes, faces, or things in the real world will be shared with this site."
        }
        requestXRPermissionsVC.titleLabel.text = title
        requestXRPermissionsVC.messageLabel.text = message
        
        // Create and configure alert controller
        let alertController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .alert
        )
        
        alertController.view.addSubview(requestXRPermissionsVC.view)
        requestXRPermissionsVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Set constraints
        NSLayoutConstraint.activate([
            requestXRPermissionsVC.view.topAnchor.constraint(equalTo: alertController.view.topAnchor),
            requestXRPermissionsVC.view.bottomAnchor.constraint(equalTo: alertController.view.bottomAnchor),
            requestXRPermissionsVC.view.leadingAnchor.constraint(equalTo: alertController.view.leadingAnchor),
            requestXRPermissionsVC.view.trailingAnchor.constraint(equalTo: alertController.view.trailingAnchor),
            requestXRPermissionsVC.view.heightAnchor.constraint(equalToConstant: height + 100) // Add some extra space for the title/message
        ])
        
        // Configure alert size
        alertController.preferredContentSize = CGSize(width: 300, height: height + 140)
        
        // Add action buttons
        let negativeAction: UIAlertAction
        if forceShowPermissionsPopup {
            negativeAction = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
        } else {
            negativeAction = UIAlertAction(title: "Deny", style: .cancel) { _ in
                authorizationGranted(.denied)
            }
        }
        alertController.addAction(negativeAction)
        forceShowPermissionsPopup = false
        
        let confirmAction = UIAlertAction(title: "Confirm", style: .default) { _ in
            if let minimalCell = blockSelf?.requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? SwitchInputTableViewCell {
                standardUserDefaults.set(minimalCell.switchControl.isOn, forKey: Constant.minimalWebXREnabled())
            }
            if let liteCell = blockSelf?.requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? SwitchInputTableViewCell {
                standardUserDefaults.set(liteCell.switchControl.isOn, forKey: Constant.liteModeWebXREnabled())
            }
            if let worldSensingCell = blockSelf?.requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 2, section: 0)) as? SwitchInputTableViewCell {
                standardUserDefaults.set(worldSensingCell.switchControl.isOn, forKey: Constant.worldSensingWebXREnabled())
            }
            if let videoCameraAccessCell = blockSelf?.requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 3, section: 0)) as? SwitchInputTableViewCell {
                standardUserDefaults.set(videoCameraAccessCell.switchControl.isOn, forKey: Constant.videoCameraAccessWebXREnabled())
            }
            
            switch blockSelf?.webXRAuthorizationRequested {
            case .minimal?:
                if standardUserDefaults.bool(forKey: Constant.liteModeWebXREnabled()) {
                    authorizationGranted(.lite)
                } else if standardUserDefaults.bool(forKey: Constant.minimalWebXREnabled()) {
                    guard let minimalControl = blockSelf?.requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 2, section: 0)) as? SegmentedControlTableViewCell else { return }
                    
                    var newDict = [AnyHashable : Any]()
                    if let dict = allowedMinimalSites {
                        newDict = dict
                    }
                    if minimalControl.segmentedControl.selectedSegmentIndex == 1 {
                        newDict[currentSite] = "YES"
                    } else {
                        newDict[currentSite] = nil
                    }
                    UserDefaults.standard.set(newDict, forKey: Constant.allowedMinimalSitesKey())
                    authorizationGranted(.minimal)
                } else {
                    authorizationGranted(.denied)
                }
            case .lite?:
                authorizationGranted(standardUserDefaults.bool(forKey: Constant.liteModeWebXREnabled()) ? .lite : .denied)
            case .worldSensing?:
                if standardUserDefaults.bool(forKey: Constant.liteModeWebXREnabled()) {
                    authorizationGranted(.lite)
                } else if standardUserDefaults.bool(forKey: Constant.worldSensingWebXREnabled()) {
                    guard let worldControl = blockSelf?.requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 3, section: 0)) as? SegmentedControlTableViewCell else { return }
                    
                    var newDict = [AnyHashable : Any]()
                    if let dict = allowedWorldSensingSites {
                        newDict = dict
                    }
                    if worldControl.segmentedControl.selectedSegmentIndex == 1 {
                        newDict[currentSite] = "YES"
                    } else {
                        newDict[currentSite] = nil
                    }
                    UserDefaults.standard.set(newDict, forKey: Constant.allowedWorldSensingSitesKey())
                    authorizationGranted(.worldSensing)
                } else if standardUserDefaults.bool(forKey: Constant.minimalWebXREnabled()) {
                    authorizationGranted(.minimal)
                } else {
                    authorizationGranted(.denied)
                }
            case .videoCameraAccess?:
                if standardUserDefaults.bool(forKey: Constant.videoCameraAccessWebXREnabled()) {
                    guard let videoControl = blockSelf?.requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 4, section: 0)) as? SegmentedControlTableViewCell else { return }
                    
                    var newDict = [AnyHashable : Any]()
                    if let dict = allowedVideoCameraSites {
                        newDict = dict
                    }
                    if videoControl.segmentedControl.selectedSegmentIndex == 1 {
                        newDict[currentSite] = "YES"
                    } else {
                        newDict[currentSite] = nil
                    }
                    UserDefaults.standard.set(newDict, forKey: Constant.allowedVideoCameraSitesKey())
                    authorizationGranted(.videoCameraAccess)
                } else if standardUserDefaults.bool(forKey: Constant.liteModeWebXREnabled()) {
                    authorizationGranted(.lite)
                } else if standardUserDefaults.bool(forKey: Constant.worldSensingWebXREnabled()) {
                    authorizationGranted(.worldSensing)
                } else if standardUserDefaults.bool(forKey: Constant.minimalWebXREnabled()) {
                    authorizationGranted(.minimal)
                } else {
                    authorizationGranted(.denied)
                }
            default:
                authorizationGranted(.denied)
            }
        }
        alertController.addAction(confirmAction)
        
        permissionsPopup = alertController
        viewController?.present(alertController, animated: true)
    }
    
    @objc func switchValueDidChange(sender: UISwitch) {
        let liteCell = requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 1, section: 0)) as? SwitchInputTableViewCell
        let worldSensingCell = requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 2, section: 0)) as? SwitchInputTableViewCell
        let videoCameraAccessCell = requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 3, section: 0)) as? SwitchInputTableViewCell
        let minimalControl = requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 2, section: 0)) as? SegmentedControlTableViewCell
        let worldControl = requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 3, section: 0)) as? SegmentedControlTableViewCell
        let videoControl = requestXRPermissionsVC?.tableView.cellForRow(at: IndexPath(row: 4, section: 0)) as? SegmentedControlTableViewCell
        
        switch sender.tag {
        case 0:
            if sender.isOn {
                liteCell?.switchControl.isEnabled = true
                liteCell?.labelTitle.isEnabled = true
                worldSensingCell?.switchControl.isEnabled = true
                worldSensingCell?.labelTitle.isEnabled = true
                minimalControl?.segmentedControl.isEnabled = true
            } else {
                liteCell?.switchControl.setOn(false, animated: true)
                liteCell?.switchControl.isEnabled = false
                liteCell?.labelTitle.isEnabled = false
                worldSensingCell?.switchControl.setOn(false, animated: true)
                worldSensingCell?.switchControl.isEnabled = false
                worldSensingCell?.labelTitle.isEnabled = false
                videoCameraAccessCell?.switchControl.setOn(false, animated: true)
                videoCameraAccessCell?.switchControl.isEnabled = false
                videoCameraAccessCell?.labelTitle.isEnabled = false
                minimalControl?.segmentedControl.isEnabled = false
                worldControl?.segmentedControl.isEnabled = false
                videoControl?.segmentedControl.isEnabled = false
            }
        case 1:
            if sender.isOn {
                worldSensingCell?.switchControl.setOn(true, animated: true)
                worldSensingCell?.switchControl.isEnabled = false
                worldSensingCell?.labelTitle.isEnabled = false
                videoCameraAccessCell?.switchControl.setOn(false, animated: true)
                videoCameraAccessCell?.switchControl.isEnabled = false
                videoCameraAccessCell?.labelTitle.isEnabled = false
                minimalControl?.segmentedControl.isEnabled = false
                worldControl?.segmentedControl.isEnabled = false
                videoControl?.segmentedControl.isEnabled = false
            } else {
                minimalControl?.segmentedControl.isEnabled = true
                worldSensingCell?.switchControl.isEnabled = true
                worldSensingCell?.labelTitle.isEnabled = true
                worldControl?.segmentedControl.isEnabled = true
                videoCameraAccessCell?.switchControl.isEnabled = true
                videoCameraAccessCell?.labelTitle.isEnabled = true
            }
        case 2:
            if sender.isOn {
                videoCameraAccessCell?.switchControl.isEnabled = true
                videoCameraAccessCell?.labelTitle.isEnabled = true
                worldControl?.segmentedControl.isEnabled = true
            } else {
                videoCameraAccessCell?.switchControl.setOn(false, animated: true)
                videoCameraAccessCell?.switchControl.isEnabled = false
                videoCameraAccessCell?.labelTitle.isEnabled = false
                worldControl?.segmentedControl.isEnabled = false
                videoControl?.segmentedControl.isEnabled = false
            }
        case 3:
            if sender.isOn {
                videoControl?.segmentedControl.isEnabled = true
            } else {
                videoControl?.segmentedControl.isEnabled = false
            }
        default:
            print("Unknown switch control toggled")
        }
    }
    
    // MARK: Alert Controller TableView Functions
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch webXRAuthorizationRequested {
        case .minimal:
            return 3
        case .lite:
            return 3
        case .worldSensing:
            return 4
        case .videoCameraAccess:
            return 5
        default:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0, 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchInputTableViewCell", for: indexPath) as! SwitchInputTableViewCell
            cell.switchControl.addTarget(self, action: #selector(switchValueDidChange(sender:)), for: .touchUpInside)
            cell.switchControl.tag = indexPath.row
            
            if indexPath.row == 0 {
                cell.labelTitle.text = "Device Motion"
                cell.switchControl.isOn = UserDefaults.standard.bool(forKey: Constant.minimalWebXREnabled())
            } else if indexPath.row == 1 {
                cell.labelTitle.text = "Lite Mode"
                cell.learnMoreButton.isHidden = false
                cell.learnMoreButton.addTarget(self, action: #selector(learnMoreLiteModeTapped), for: .touchUpInside)
                cell.switchControl.isOn = UserDefaults.standard.bool(forKey: Constant.liteModeWebXREnabled())
                if !UserDefaults.standard.bool(forKey: Constant.minimalWebXREnabled()) {
                    cell.switchControl.isEnabled = false
                    cell.labelTitle.isEnabled = false
                }
            }
            return cell
        case 2:
            switch webXRAuthorizationRequested {
            case .minimal:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentedControlTableViewCell", for: indexPath) as! SegmentedControlTableViewCell
                cell.segmentedControl.tag = indexPath.row
                
                if !UserDefaults.standard.bool(forKey: Constant.minimalWebXREnabled())
                    || UserDefaults.standard.bool(forKey: Constant.liteModeWebXREnabled())
                {
                    cell.segmentedControl.isEnabled = false
                }
                let allowedMinimalSites = UserDefaults.standard.dictionary(forKey: Constant.allowedMinimalSitesKey())
                if let site = site, allowedMinimalSites?[site] != nil {
                    cell.segmentedControl.selectedSegmentIndex = 1
                }
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchInputTableViewCell", for: indexPath) as! SwitchInputTableViewCell
                cell.switchControl.addTarget(self, action: #selector(switchValueDidChange(sender:)), for: .touchUpInside)
                cell.switchControl.tag = indexPath.row
                
                cell.labelTitle.text = "World Sensing"
                cell.switchControl.isOn = UserDefaults.standard.bool(forKey: Constant.worldSensingWebXREnabled())
                if !UserDefaults.standard.bool(forKey: Constant.minimalWebXREnabled())
                    || UserDefaults.standard.bool(forKey: Constant.liteModeWebXREnabled())
                {
                    cell.switchControl.isEnabled = false
                    cell.labelTitle.isEnabled = false
                }
                return cell
            }
        case 3:
            switch webXRAuthorizationRequested {
            case .worldSensing:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentedControlTableViewCell", for: indexPath) as! SegmentedControlTableViewCell
                cell.segmentedControl.tag = indexPath.row
                
                if !UserDefaults.standard.bool(forKey: Constant.worldSensingWebXREnabled())
                    || UserDefaults.standard.bool(forKey: Constant.liteModeWebXREnabled())
                {
                    cell.segmentedControl.isEnabled = false
                }
                let allowedWorldSensingSites = UserDefaults.standard.dictionary(forKey: Constant.allowedWorldSensingSitesKey())
                if let site = site, allowedWorldSensingSites?[site] != nil {
                    cell.segmentedControl.selectedSegmentIndex = 1
                }
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchInputTableViewCell", for: indexPath) as! SwitchInputTableViewCell
                cell.switchControl.addTarget(self, action: #selector(switchValueDidChange(sender:)), for: .touchUpInside)
                cell.switchControl.tag = indexPath.row
                
                cell.labelTitle.text = "Video Camera Access"
                cell.switchControl.isOn = UserDefaults.standard.bool(forKey: Constant.videoCameraAccessWebXREnabled())
                if !UserDefaults.standard.bool(forKey: Constant.minimalWebXREnabled())
                    || UserDefaults.standard.bool(forKey: Constant.liteModeWebXREnabled())
                    || !UserDefaults.standard.bool(forKey: Constant.worldSensingWebXREnabled())
                {
                    cell.switchControl.isEnabled = false
                    cell.labelTitle.isEnabled = false
                }
                return cell
            }
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentedControlTableViewCell", for: indexPath) as! SegmentedControlTableViewCell
            cell.segmentedControl.tag = indexPath.row
            
            if !UserDefaults.standard.bool(forKey: Constant.videoCameraAccessWebXREnabled()) {
                cell.segmentedControl.isEnabled = false
            }
            let allowedVideoCameraSites = UserDefaults.standard.dictionary(forKey: Constant.allowedVideoCameraSitesKey())
            if let site = site, allowedVideoCameraSites?[site] != nil {
                cell.segmentedControl.selectedSegmentIndex = 1
            }
            return cell
        }
    }

    // MARK: private

//    func setupAppearance() {
//        let largeFont = UIFont.boldSystemFont(ofSize: 17)
//        let smallFont = UIFont.systemFont(ofSize: 14)
//        PopupDialogDefaultView.appearance().backgroundColor = UIColor.clear
//        PopupDialogDefaultView.appearance().titleFont = largeFont
//        PopupDialogDefaultView.appearance().titleColor = UIColor.black
//        PopupDialogDefaultView.appearance().messageFont = smallFont
//        PopupDialogDefaultView.appearance().messageColor = UIColor.black
//
//        PopupDialogContainerView.appearance().cornerRadius = 13
//        
//        PopupDialogOverlayView.appearance().color = UIColor(white: 0, alpha: 0.5)
//        PopupDialogOverlayView.appearance().blurRadius = 10
//        PopupDialogOverlayView.appearance().blurEnabled = true
//        PopupDialogOverlayView.appearance().liveBlurEnabled = false
//        PopupDialogOverlayView.appearance().opacity = 0.5
//
//        DefaultButton.appearance().titleFont = largeFont
//        DefaultButton.appearance().titleColor = UIColor.blue
//        DefaultButton.appearance().buttonColor = UIColor.clear
//        DefaultButton.appearance().separatorColor = UIColor(white: 0.8, alpha: 1)
//
//        CancelButton.appearance().titleColor = UIColor.gray
//        CancelButton.appearance().titleFont = largeFont
//        
//        DestructiveButton.appearance().titleColor = UIColor.red
//        DestructiveButton.appearance().titleFont = largeFont
//    }
    
    @objc func learnMoreLiteModeTapped() {
        let alert = UIAlertController(title: "What's Lite Mode?", message: """
            Lite Mode is privacy-focused and sends less information to WebXR sites.

            When Lite Mode is on, only one real world plane is shared.
            Lite Mode enables face-based experiences, but will not recognize images nor share camera access.
        """, preferredStyle: .alert)
        let ok = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(ok)
        permissionsPopup?.present(alert, animated: true)
    }
}
