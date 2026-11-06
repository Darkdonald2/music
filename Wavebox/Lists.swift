import UIKit

// MARK: - Row

final class ItemCell: UITableViewCell {
    private let art = RemoteImageView(frame: .zero)
    private let title = UILabel()
    private let subtitle = UILabel()
    private let moreButton = UIButton(type: .system)
    var onMore: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.bg
        let selected = UIView()
        selected.backgroundColor = Theme.card
        selectedBackgroundView = selected

        title.textColor = Theme.text
        title.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        subtitle.textColor = Theme.sub
        subtitle.font = UIFont.systemFont(ofSize: 12)

        let labels = UIStackView(arrangedSubviews: [title, subtitle])
        labels.axis = .vertical
        labels.spacing = 3
        labels.translatesAutoresizingMaskIntoConstraints = false

        moreButton.setImage(Icons.more(), for: .normal)
        moreButton.tintColor = Theme.sub
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)

        contentView.addSubview(art)
        contentView.addSubview(labels)
        contentView.addSubview(moreButton)
        NSLayoutConstraint.activate([
            art.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            art.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            art.widthAnchor.constraint(equalToConstant: 46),
            art.heightAnchor.constraint(equalToConstant: 46),
            labels.leadingAnchor.constraint(equalTo: art.trailingAnchor, constant: 10),
            labels.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labels.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -4),
            moreButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            moreButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 44),
            moreButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func moreTapped() { onMore?() }

    func configure(_ item: Item) {
        switch item {
        case .track(let t):
            title.text = t.title
            var sub = t.artist
            if let badge = t.badge { sub = sub.isEmpty ? badge : "\(badge) · \(sub)" }
            if t.stream == nil { sub = sub.isEmpty ? "No preview" : "No preview · \(sub)" }
            subtitle.text = sub
            art.set(t.artwork)
            moreButton.isHidden = false
        case .album(_, let name, let sub, let artwork):
            title.text = name
            subtitle.text = "Album · \(sub)"
            art.set(artwork)
            moreButton.isHidden = true
        }
    }
}

// MARK: - Generic list of tracks / albums

class ItemListController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var items: [Item] = []
    let tableView = UITableView(frame: .zero, style: .plain)
    let header = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .whiteLarge)
    private let messageLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg

        header.axis = .vertical
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = Theme.bg
        tableView.separatorColor = UIColor(white: 0.2, alpha: 1)
        tableView.rowHeight = 62
        tableView.keyboardDismissMode = .onDrag
        tableView.tableFooterView = UIView()
        tableView.register(ItemCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)

        messageLabel.textColor = Theme.sub
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        view.addSubview(spinner)

        let guide = view.safeAreaLayoutGuide
        let collapsed = header.heightAnchor.constraint(equalToConstant: 0)
        collapsed.priority = .defaultLow
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: guide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collapsed,
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 60),
            messageLabel.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 60)
        ])
    }

    func setLoading(_ loading: Bool) {
        if loading {
            messageLabel.text = nil
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    func show(_ newItems: [Item], emptyMessage: String) {
        setLoading(false)
        items = newItems
        messageLabel.text = newItems.isEmpty ? emptyMessage : nil
        tableView.reloadData()
    }

    // MARK: Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ItemCell
        let item = items[indexPath.row]
        cell.configure(item)
        cell.onMore = { [weak self] in
            if case .track(let t) = item { self?.showActions(for: t) }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch items[indexPath.row] {
        case .track(let t):
            guard t.stream != nil else {
                showActions(for: t)
                return
            }
            var playable: [Track] = []
            var start = 0
            for (i, item) in items.enumerated() {
                if case .track(let x) = item, x.stream != nil {
                    if i == indexPath.row { start = playable.count }
                    playable.append(x)
                }
            }
            AudioPlayer.shared.play(playable, at: start)
        case .album(let id, let name, _, _):
            let list = ItemListController()
            list.title = name
            navigationController?.pushViewController(list, animated: true)
            list.loadViewIfNeeded()
            list.setLoading(true)
            API.archiveTracks(id: id) { [weak list] result in
                switch result {
                case .success(let tracks): list?.show(tracks, emptyMessage: "No playable audio in this item.")
                case .failure(let e): list?.show([], emptyMessage: e.localizedDescription)
                }
            }
        }
    }

    // MARK: Actions

    func openWeb(_ source: Source, query: String) {
        guard let url = source.webURL(query: query) else { return }
        AudioPlayer.shared.pause()
        let web = WebViewController(url: url, title: source.title)
        navigationController?.pushViewController(web, animated: true)
    }

    func showActions(for track: Track) {
        let sheet = UIAlertController(title: track.title, message: track.artist.isEmpty ? nil : track.artist,
                                      preferredStyle: .actionSheet)
        let query = track.isLive ? track.title : "\(track.artist) \(track.title)"
        if !track.isLive {
            sheet.addAction(UIAlertAction(title: "Full song on YouTube", style: .default) { [weak self] _ in
                self?.openWeb(.youtube, query: query)
            })
            sheet.addAction(UIAlertAction(title: "Find on SoundCloud", style: .default) { [weak self] _ in
                self?.openWeb(.soundcloud, query: query)
            })
        }
        if track.download != nil {
            sheet.addAction(UIAlertAction(title: "Download", style: .default) { [weak self] _ in
                self?.toast("Downloading…")
                Library.download(track) { ok in
                    // Wait for the "Downloading…" notice to clear before showing the result.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        let top = UIApplication.shared.keyWindow?.rootViewController
                        (top?.presentedViewController ?? top)?.toast(ok ? "Saved to Library" : "Download failed")
                    }
                }
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }
}

// MARK: - Browse tab

final class BrowseViewController: ItemListController, UISearchBarDelegate {
    private let searchBar = UISearchBar()
    private let strip = UIScrollView()
    private var chips: [UIButton] = []
    private var source: Source = .popular
    private var requestID = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Wavebox"

        searchBar.delegate = self
        searchBar.barStyle = .black
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = Theme.tint
        searchBar.keyboardAppearance = .dark
        header.addArrangedSubview(searchBar)

        strip.showsHorizontalScrollIndicator = false
        strip.heightAnchor.constraint(equalToConstant: 46).isActive = true
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        strip.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: strip.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: strip.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: strip.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: strip.bottomAnchor, constant: -8),
            row.heightAnchor.constraint(equalToConstant: 34)
        ])
        for s in Source.allCases {
            let chip = UIButton(type: .custom)
            chip.tag = s.rawValue
            chip.setTitle(s.title, for: .normal)
            chip.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            chip.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
            chip.layer.cornerRadius = 17
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chips.append(chip)
            row.addArrangedSubview(chip)
        }
        header.addArrangedSubview(strip)

        styleChips()
        reload()
    }

    private func styleChips() {
        for chip in chips {
            let on = chip.tag == source.rawValue
            chip.backgroundColor = on ? Theme.tint : Theme.card
            chip.setTitleColor(on ? .white : Theme.sub, for: .normal)
        }
        switch source {
        case .popular: searchBar.placeholder = "Search songs and artists"
        case .radio: searchBar.placeholder = "Search radio stations"
        default: searchBar.placeholder = "Search \(source.title)"
        }
    }

    @objc private func chipTapped(_ sender: UIButton) {
        guard let s = Source(rawValue: sender.tag) else { return }
        source = s
        styleChips()
        reload()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        reload()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty && !source.isWeb { reload() }
    }

    private func reload() {
        requestID += 1
        let id = requestID
        let query = searchBar.text ?? ""

        if source.isWeb {
            show([], emptyMessage: "\(source.title) opens inside the app.\nType a search above and tap Search.\n\nIt plays through the official site, so audio stops when the screen locks.")
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                openWeb(source, query: query)
            }
            return
        }

        show([], emptyMessage: "")
        setLoading(true)
        let current = source
        API.fetch(current, query: query) { [weak self] result in
            guard let self = self, id == self.requestID else { return }
            switch result {
            case .success(let items):
                self.show(items, emptyMessage: "Nothing found.")
            case .failure(let e):
                self.show([], emptyMessage: e.localizedDescription)
                if let api = e as? APIError, case .needsJamendoKey = api {
                    self.askForJamendoKey()
                }
            }
        }
    }

    private func askForJamendoKey() {
        let alert = UIAlertController(title: "Jamendo key",
                                      message: "Create a free app at devportal.jamendo.com and paste its Client ID here.",
                                      preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Client ID" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            let key = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty else { return }
            API.jamendoKey = key
            self?.reload()
        })
        present(alert, animated: true)
    }
}

// MARK: - Library tab

final class LibraryViewController: ItemListController, UIDocumentPickerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Library"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Import", style: .plain,
                                                            target: self, action: #selector(importTapped))
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: Library.changed, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    @objc private func refresh() {
        show(Library.tracks().map { Item.track($0) },
             emptyMessage: "No offline music yet.\n\nDownload tracks from Audius, Jamendo or the Archive, tap Import, or copy audio files into Wavebox's Documents folder with Filza.")
    }

    @objc private func importTapped() {
        let picker = UIDocumentPickerViewController(documentTypes: ["public.audio"], in: .import)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        urls.forEach { Library.importFile($0) }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, case .track(let t) = items[indexPath.row], let file = t.stream else { return }
        try? FileManager.default.removeItem(at: file)
        items.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}
