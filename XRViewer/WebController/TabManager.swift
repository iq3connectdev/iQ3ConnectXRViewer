import Foundation
import UIKit
import WebKit

/// A single browser tab. Holds its web view strongly (the view hierarchy only retains the
/// *active* tab's web view, so a strong ref here keeps backgrounded tabs from being deallocated).
final class Tab {
    /// Strong: keeps a detached/background tab's web view alive.
    var webView: WKWebView?
    /// Updated whenever the tab is selected; used for LRU eviction under the live-tab cap.
    var lastAccessed = Date()
    /// For lazily-restored tabs: the URL to load the first time the tab becomes active. Cleared once
    /// loaded. nil for tabs whose web view already has content.
    var pendingURL: String?
    /// Cached thumbnail of the page (unused by the strip UI; kept for possible future grid view).
    var snapshot: UIImage?
    /// Cached favicon shown in the tab strip.
    var favicon: UIImage?

    init(webView: WKWebView?) {
        self.webView = webView
    }

    /// Live URL if loaded, else the pending (not-yet-loaded) URL. nil/empty → treated as no URL.
    var urlString: String? {
        if let u = webView?.url?.absoluteString, !u.isEmpty { return u }
        if let p = pendingURL, !p.isEmpty { return p }
        return nil
    }
    var title: String? { return webView?.title }
}

/// Persists the open tabs' URLs + selected index across app relaunches (UserDefaults).
enum TabPersistence {
    private static let urlsKey = "persistedTabURLs"
    private static let selectedKey = "persistedSelectedTabIndex"

    static func save(urls: [String], selectedIndex: Int) {
        UserDefaults.standard.set(urls, forKey: urlsKey)
        UserDefaults.standard.set(selectedIndex, forKey: selectedKey)
    }

    static func load() -> (urls: [String], selectedIndex: Int)? {
        guard let urls = UserDefaults.standard.array(forKey: urlsKey) as? [String], !urls.isEmpty else {
            return nil
        }
        let idx = min(max(0, UserDefaults.standard.integer(forKey: selectedKey)), urls.count - 1)
        return (urls, idx)
    }
}

protocol TabManagerDelegate: AnyObject {
    func tabManager(_ manager: TabManager, didSelect tab: Tab?, previous: Tab?)
}

final class TabManager {

    weak var delegate: TabManagerDelegate?

    private(set) var tabs: [Tab] = []
    private(set) var selectedIndex: Int = -1

    var selectedTab: Tab? {
        return tabs.indices.contains(selectedIndex) ? tabs[selectedIndex] : nil
    }

    var count: Int { return tabs.count }

    func resetToSingleTab(_ tab: Tab) {
        tabs = [tab]
        selectedIndex = 0
    }

    @discardableResult
    func addTab(_ tab: Tab, select: Bool = false) -> Tab {
        tabs.append(tab)
        if select {
            selectTab(tab)
        }
        return tab
    }

    func moveTab(from: Int, to: Int) {
        guard tabs.indices.contains(from), tabs.indices.contains(to), from != to else { return }
        let previouslySelected = selectedTab
        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: to)
        if let previouslySelected = previouslySelected,
           let idx = tabs.firstIndex(where: { $0 === previouslySelected }) {
            selectedIndex = idx
        }
    }

    func selectTab(_ tab: Tab?) {
        guard let tab = tab, let index = tabs.firstIndex(where: { $0 === tab }) else { return }
        tab.lastAccessed = Date()
        let previous = selectedTab
        selectedIndex = index
        delegate?.tabManager(self, didSelect: tab, previous: previous)
    }

    func removeTab(_ tab: Tab) {
        guard let index = tabs.firstIndex(where: { $0 === tab }) else { return }
        let wasSelected = (index == selectedIndex)
        tabs.remove(at: index)

        if tabs.isEmpty {
            selectedIndex = -1
            return
        }
        if wasSelected {
            let newIndex = min(index, tabs.count - 1)
            selectedIndex = -1 // force selectTab to treat this as a real change
            selectTab(tabs[newIndex])
        } else if index < selectedIndex {
            selectedIndex -= 1
        }
    }
}
