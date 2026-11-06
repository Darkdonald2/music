import UIKit
import WebKit

// MARK: - Mini player bar

final class MiniPlayerView: UIView {
    private let art = RemoteImageView(frame: .zero)
    private let title = UILabel()
    private let subtitle = UILabel()
    private let playButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.11, alpha: 1)
        translatesAutoresizingMaskIntoConstraints = false

        let line = UIView()
        line.backgroundColor = UIColor(white: 0.22, alpha: 1)
        line.translatesAutoresizingMaskIntoConstraints = false

        title.textColor = Theme.text
        title.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        subtitle.textColor = Theme.sub
        subtitle.font = UIFont.systemFont(ofSize: 12)
        let labels = UIStackView(arrangedSubviews: [title, subtitle])
        labels.axis = .vertical
        labels.spacing = 2
        labels.translatesAutoresizingMaskIntoConstraints = false

        playButton.tintColor = Theme.text
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        nextButton.tintColor = Theme.text
        nextButton.setImage(Icons.next(22), for: .normal)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        [line, art, labels, playButton, nextButton].forEach { addSubview($0) }
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: topAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 0.5),
            art.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            art.centerYAnchor.constraint(equalTo: centerYAnchor),
            art.widthAnchor.constraint(equalToConstant: 40),
            art.heightAnchor.constraint(equalToConstant: 40),
            labels.leadingAnchor.constraint(equalTo: art.trailingAnchor, constant: 10),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),
            labels.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -6),
            playButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44),
            nextButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 44),
            nextButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func playTapped() { AudioPlayer.shared.toggle() }
    @objc private func nextTapped() { AudioPlayer.shared.next() }
    @objc private func tapped() { onTap?() }

    private var shownArt: URL?

    func refresh() {
        let p = AudioPlayer.shared
        guard let t = p.current else { return }
        title.text = t.title
        subtitle.text = t.artist
        if shownArt != t.artwork || t.artwork == nil {
            shownArt = t.artwork
            art.set(t.artwork)
        }
        playButton.setImage(p.isPlaying ? Icons.pause(22) : Icons.play(22), for: .normal)
    }
}

// MARK: - Root tab bar

final class MainTabBarController: UITabBarController {
    private let mini = MiniPlayerView()
    private let miniHeight: CGFloat = 58

    override func viewDidLoad() {
        super.viewDidLoad()

        let browse = UINavigationController(rootViewController: BrowseViewController())
        browse.tabBarItem = UITabBarItem(title: "Browse", image: Icons.search(), tag: 0)
        let library = UINavigationController(rootViewController: LibraryViewController())
        library.tabBarItem = UITabBarItem(title: "Library", image: Icons.library(), tag: 1)
        viewControllers = [browse, library]

        mini.isHidden = true
        mini.onTap = { [weak self] in
            self?.present(NowPlayingViewController(), animated: true)
        }
        view.addSubview(mini)
        NSLayoutConstraint.activate([
            mini.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mini.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mini.bottomAnchor.constraint(equalTo: tabBar.topAnchor),
            mini.heightAnchor.constraint(equalToConstant: miniHeight)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(playerChanged),
                                               name: AudioPlayer.changed, object: nil)
    }

    @objc private func playerChanged() {
        guard AudioPlayer.shared.current != nil else { return }
        if mini.isHidden {
            mini.isHidden = false
            viewControllers?.forEach { $0.additionalSafeAreaInsets.bottom = miniHeight }
        }
        mini.refresh()
    }
}

// MARK: - Full-screen player

final class NowPlayingViewController: UIViewController {
    private let art = RemoteImageView(frame: .zero)
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let slider = UISlider()
    private let elapsedLabel = UILabel()
    private let remainingLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private var shownArt: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg

        let close = UIButton(type: .system)
        close.setImage(Icons.chevronDown(), for: .normal)
        close.tintColor = Theme.text
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(close)

        art.layer.cornerRadius = 10

        titleLabel.textColor = Theme.text
        titleLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        artistLabel.textColor = Theme.sub
        artistLabel.font = UIFont.systemFont(ofSize: 15)
        artistLabel.textAlignment = .center

        slider.minimumTrackTintColor = Theme.tint
        slider.maximumTrackTintColor = UIColor(white: 0.3, alpha: 1)
        slider.addTarget(self, action: #selector(sliderReleased), for: [.touchUpInside, .touchUpOutside])

        for label in [elapsedLabel, remainingLabel] {
            label.textColor = Theme.sub
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }
        let spacer = UIView()
        let times = UIStackView(arrangedSubviews: [elapsedLabel, spacer, remainingLabel])
        times.axis = .horizontal

        let prev = UIButton(type: .system)
        prev.setImage(Icons.previous(30), for: .normal)
        prev.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        let next = UIButton(type: .system)
        next.setImage(Icons.next(30), for: .normal)
        next.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        for b in [prev, playButton, next] {
            b.tintColor = Theme.text
            b.heightAnchor.constraint(equalToConstant: 56).isActive = true
        }
        let controls = UIStackView(arrangedSubviews: [prev, playButton, next])
        controls.axis = .horizontal
        controls.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [titleLabel, artistLabel, slider, times, controls])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(18, after: artistLabel)
        stack.setCustomSpacing(2, after: slider)
        stack.setCustomSpacing(14, after: times)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(art)
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        let artWidth = art.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -96)
        artWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: guide.topAnchor, constant: 4),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            close.widthAnchor.constraint(equalToConstant: 44),
            close.heightAnchor.constraint(equalToConstant: 44),
            art.topAnchor.constraint(equalTo: close.bottomAnchor, constant: 8),
            art.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            artWidth,
            art.heightAnchor.constraint(equalTo: art.widthAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: art.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            stack.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20)
        ])

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(refresh), name: AudioPlayer.changed, object: nil)
        nc.addObserver(self, selector: #selector(tick), name: AudioPlayer.ticked, object: nil)
        refresh()
    }

    @objc private func closeTapped() { dismiss(animated: true) }
    @objc private func playTapped() { AudioPlayer.shared.toggle() }
    @objc private func nextTapped() { AudioPlayer.shared.next() }
    @objc private func prevTapped() { AudioPlayer.shared.previous() }

    @objc private func sliderReleased() {
        let p = AudioPlayer.shared
        if p.duration > 0 { p.seek(to: Double(slider.value) * p.duration) }
    }

    @objc private func refresh() {
        let p = AudioPlayer.shared
        guard let t = p.current else { return }
        titleLabel.text = t.title
        artistLabel.text = t.artist
        if shownArt != t.artwork || t.artwork == nil {
            shownArt = t.artwork
            art.set(t.artwork)
        }
        playButton.setImage(p.isPlaying ? Icons.pause(34) : Icons.play(34), for: .normal)
        slider.isEnabled = !t.isLive
        tick()
    }

    private func clock(_ seconds: Double) -> String {
        let s = Int(max(seconds, 0))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    @objc private func tick() {
        let p = AudioPlayer.shared
        if p.current?.isLive == true {
            elapsedLabel.text = "LIVE"
            remainingLabel.text = ""
            slider.value = 0
            return
        }
        elapsedLabel.text = clock(p.elapsed)
        remainingLabel.text = p.duration > 0 ? "-" + clock(p.duration - p.elapsed) : "--:--"
        if !slider.isTracking {
            slider.value = p.duration > 0 ? Float(p.elapsed / p.duration) : 0
        }
    }
}

// MARK: - In-app web page (official YouTube / SoundCloud sites)

final class WebViewController: UIViewController, WKNavigationDelegate {
    private let startURL: URL
    private var webView: WKWebView!
    private let spinner = UIActivityIndicatorView(style: .white)

    init(url: URL, title: String) {
        startURL = url
        super.init(nibName: nil, bundle: nil)
        self.title = title
        hidesBottomBarWhenPushed = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = Theme.bg
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: guide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
        ])

        spinner.hidesWhenStopped = true
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadPage)),
            UIBarButtonItem(customView: spinner)
        ]
        webView.load(URLRequest(url: startURL))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            // Stop any audio or video the page is still playing.
            webView.loadHTMLString("", baseURL: nil)
        }
    }

    @objc private func reloadPage() { webView.reload() }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        spinner.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Keep everything inside the app instead of bouncing to app links.
        if let scheme = navigationAction.request.url?.scheme?.lowercased(),
           !["http", "https", "about", "blob", "data"].contains(scheme) {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
