import UIKit

final class BookmarksViewController: UITableViewController {

    /// Called with a bookmark's URL after the screen has dismissed itself.
    var onSelect: ((String) -> Void)?

    private var items: [Bookmark] = []
    private let emptyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Bookmarks"
        overrideUserInterfaceStyle = .light
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped))

        emptyLabel.text = "No bookmarks yet.\nTap the bookmark button on a page to save it."
        emptyLabel.textColor = .gray
        emptyLabel.font = .systemFont(ofSize: 15)
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center

        items = BrowserDataStore.shared.bookmarks
        updateEmptyState()
    }

    private func updateEmptyState() {
        tableView.backgroundView = items.isEmpty ? emptyLabel : nil
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "bookmarkCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "bookmarkCell")
        let bookmark = items[indexPath.row]
        cell.textLabel?.text = bookmark.title.isEmpty ? bookmark.url : bookmark.title
        cell.detailTextLabel?.text = bookmark.url
        cell.detailTextLabel?.textColor = .gray
        cell.imageView?.image = UIImage(systemName: "bookmark.fill")
        cell.imageView?.tintColor = .systemBlue
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let url = items[indexPath.row].url
        dismiss(animated: true) { [weak self] in
            self?.onSelect?(url)
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let url = items[indexPath.row].url
        BrowserDataStore.shared.removeBookmark(url: url)
        items.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        updateEmptyState()
    }
}
