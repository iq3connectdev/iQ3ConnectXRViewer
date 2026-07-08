import Foundation

struct VisitedPage: Codable {
    let url: String
    var title: String
    var lastVisited: Date
    var visitCount: Int
}

struct Bookmark: Codable {
    let url: String
    var title: String
    let dateAdded: Date
}

/// A single row offered in the address-bar autocomplete list.
struct Suggestion {
    enum Kind { case search, history, bookmark }
    let kind: Kind
    let primaryText: String
    let secondaryText: String
}

final class BrowserDataStore {

    static let shared = BrowserDataStore()

    /// Cap history so the JSON file and autocomplete scans stay fast.
    private let maxHistoryEntries = 2000
    /// Number of recent unique search terms to retain for suggestions.
    private let maxSearchTerms = 200

    private(set) var history: [VisitedPage] = []
    private(set) var bookmarks: [Bookmark] = []
    /// Most-recent-first list of raw search queries the user typed.
    private(set) var searchTerms: [String] = []

    private let queue = DispatchQueue(label: "com.iq3connect.browserdatastore", qos: .utility)
    private let directory: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("BrowserData", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        history = load([VisitedPage].self, from: "history.json") ?? []
        bookmarks = load([Bookmark].self, from: "bookmarks.json") ?? []
        searchTerms = load([String].self, from: "searches.json") ?? []
    }

    /// Record a page visit. Collapses repeat visits to the same URL into one entry
    /// (bumping recency + visit count), so autocomplete favors frequently-used sites.
    func recordVisit(url: String?, title: String?) {
        guard let url = normalize(url), !url.isEmpty else { return }
        // Skip the bundled homepage and internal schemes — not real browsing history.
        guard !url.contains(HOMEPAGE_NAME), url.hasPrefix("http") else { return }

        let cleanTitle = (title?.isEmpty == false ? title : url) ?? url
        if let idx = history.firstIndex(where: { $0.url == url }) {
            history[idx].title = cleanTitle
            history[idx].lastVisited = Date()
            history[idx].visitCount += 1
        } else {
            history.insert(VisitedPage(url: url, title: cleanTitle, lastVisited: Date(), visitCount: 1), at: 0)
        }
        if history.count > maxHistoryEntries {
            history.sort { $0.lastVisited > $1.lastVisited }
            history.removeLast(history.count - maxHistoryEntries)
        }
        persist(history, to: "history.json")
    }

    func clearHistory() {
        history = []
        persist(history, to: "history.json")
    }

    // MARK: Search terms

    /// Record a raw search query (the text typed when it wasn't a URL).
    func recordSearch(_ term: String?) {
        guard let term = term?.trimmingCharacters(in: .whitespacesAndNewlines), !term.isEmpty else { return }
        searchTerms.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        searchTerms.insert(term, at: 0)
        if searchTerms.count > maxSearchTerms {
            searchTerms.removeLast(searchTerms.count - maxSearchTerms)
        }
        persist(searchTerms, to: "searches.json")
    }

    // MARK: Bookmarks

    func isBookmarked(_ url: String?) -> Bool {
        guard let url = normalize(url) else { return false }
        return bookmarks.contains { $0.url == url }
    }

    func addBookmark(url: String?, title: String?) {
        guard let url = normalize(url), !url.isEmpty, !isBookmarked(url) else { return }
        let cleanTitle = (title?.isEmpty == false ? title : url) ?? url
        bookmarks.insert(Bookmark(url: url, title: cleanTitle, dateAdded: Date()), at: 0)
        persist(bookmarks, to: "bookmarks.json")
    }

    func removeBookmark(url: String?) {
        guard let url = normalize(url) else { return }
        bookmarks.removeAll { $0.url == url }
        persist(bookmarks, to: "bookmarks.json")
    }

    /// Toggle and return the new bookmarked state for the given page.
    @discardableResult
    func toggleBookmark(url: String?, title: String?) -> Bool {
        if isBookmarked(url) {
            removeBookmark(url: url)
            return false
        } else {
            addBookmark(url: url, title: title)
            return true
        }
    }

    /// Build a ranked suggestion list for what the user has typed so far.
    /// Order: matching past searches, then most-recent/most-visited history, then bookmarks.
    func suggestions(for query: String, limit: Int = 8) -> [Suggestion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var results: [Suggestion] = []
        var seen = Set<String>()

        func add(_ s: Suggestion) {
            let key = s.primaryText.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            results.append(s)
        }

        for term in searchTerms where term.lowercased().contains(q) {
            add(Suggestion(kind: .search, primaryText: term, secondaryText: ""))
        }

        let rankedHistory = history.sorted {
            $0.visitCount != $1.visitCount ? $0.visitCount > $1.visitCount : $0.lastVisited > $1.lastVisited
        }
        for page in rankedHistory where page.url.lowercased().contains(q) || page.title.lowercased().contains(q) {
            add(Suggestion(kind: .history, primaryText: page.url, secondaryText: page.title))
        }

        for bm in bookmarks where bm.url.lowercased().contains(q) || bm.title.lowercased().contains(q) {
            add(Suggestion(kind: .bookmark, primaryText: bm.url, secondaryText: bm.title))
        }

        return Array(results.prefix(limit))
    }

    // MARK: - Persistence helpers

    private func normalize(_ url: String?) -> String? {
        return url?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        let url = directory.appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func persist<T: Encodable>(_ value: T, to file: String) {
        let url = directory.appendingPathComponent(file)
        queue.async {
            if let data = try? JSONEncoder().encode(value) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
