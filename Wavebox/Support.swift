import UIKit

enum Theme {
    static let bg = UIColor(white: 0.07, alpha: 1)
    static let card = UIColor(white: 0.14, alpha: 1)
    static let tint = UIColor(red: 1.0, green: 0.25, blue: 0.42, alpha: 1)
    static let text = UIColor.white
    static let sub = UIColor(white: 0.62, alpha: 1)
}

// MARK: - Icons (drawn in code; SF Symbols need iOS 13)

enum Icons {
    private static func draw(_ side: CGFloat, _ block: (CGFloat) -> Void) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            UIColor.black.setFill()
            UIColor.black.setStroke()
            block(side)
        }.withRenderingMode(.alwaysTemplate)
    }

    private static func triangle(_ x0: CGFloat, _ x1: CGFloat, _ s: CGFloat) -> UIBezierPath {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: x0, y: s * 0.15))
        p.addLine(to: CGPoint(x: x1, y: s * 0.5))
        p.addLine(to: CGPoint(x: x0, y: s * 0.85))
        p.close()
        return p
    }

    static func play(_ side: CGFloat = 28) -> UIImage {
        return draw(side) { s in triangle(s * 0.22, s * 0.88, s).fill() }
    }

    static func pause(_ side: CGFloat = 28) -> UIImage {
        return draw(side) { s in
            UIBezierPath(roundedRect: CGRect(x: s * 0.2, y: s * 0.15, width: s * 0.22, height: s * 0.7), cornerRadius: 2).fill()
            UIBezierPath(roundedRect: CGRect(x: s * 0.58, y: s * 0.15, width: s * 0.22, height: s * 0.7), cornerRadius: 2).fill()
        }
    }

    static func next(_ side: CGFloat = 28) -> UIImage {
        return draw(side) { s in
            triangle(s * 0.12, s * 0.72, s).fill()
            UIBezierPath(rect: CGRect(x: s * 0.76, y: s * 0.15, width: s * 0.12, height: s * 0.7)).fill()
        }
    }

    static func previous(_ side: CGFloat = 28) -> UIImage {
        return draw(side) { s in
            triangle(s * 0.88, s * 0.28, s).fill()
            UIBezierPath(rect: CGRect(x: s * 0.12, y: s * 0.15, width: s * 0.12, height: s * 0.7)).fill()
        }
    }

    static func more(_ side: CGFloat = 24) -> UIImage {
        return draw(side) { s in
            for i in 0..<3 {
                let x = s * (0.2 + 0.3 * CGFloat(i))
                UIBezierPath(ovalIn: CGRect(x: x - s * 0.08, y: s * 0.42, width: s * 0.16, height: s * 0.16)).fill()
            }
        }
    }

    static func search(_ side: CGFloat = 26) -> UIImage {
        return draw(side) { s in
            let circle = UIBezierPath(ovalIn: CGRect(x: s * 0.14, y: s * 0.14, width: s * 0.5, height: s * 0.5))
            circle.lineWidth = 2
            circle.stroke()
            let handle = UIBezierPath()
            handle.move(to: CGPoint(x: s * 0.58, y: s * 0.58))
            handle.addLine(to: CGPoint(x: s * 0.86, y: s * 0.86))
            handle.lineWidth = 2.5
            handle.lineCapStyle = .round
            handle.stroke()
        }
    }

    static func library(_ side: CGFloat = 26) -> UIImage {
        return draw(side) { s in
            for i in 0..<3 {
                let y = s * (0.24 + 0.24 * CGFloat(i))
                UIBezierPath(roundedRect: CGRect(x: s * 0.14, y: y, width: s * 0.72, height: 2.5), cornerRadius: 1).fill()
            }
        }
    }

    static func chevronDown(_ side: CGFloat = 26) -> UIImage {
        return draw(side) { s in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: s * 0.2, y: s * 0.36))
            p.addLine(to: CGPoint(x: s * 0.5, y: s * 0.64))
            p.addLine(to: CGPoint(x: s * 0.8, y: s * 0.36))
            p.lineWidth = 2.5
            p.lineCapStyle = .round
            p.lineJoinStyle = .round
            p.stroke()
        }
    }
}

// MARK: - Images

enum ImageLoader {
    private static let cache = NSCache<NSURL, UIImage>()

    static func load(_ url: URL, done: @escaping (UIImage?) -> Void) {
        if let hit = cache.object(forKey: url as NSURL) {
            done(hit)
            return
        }
        API.session.dataTask(with: url) { data, _, _ in
            let image = data.flatMap { UIImage(data: $0) }
            if let image = image { cache.setObject(image, forKey: url as NSURL) }
            DispatchQueue.main.async { done(image) }
        }.resume()
    }
}

final class RemoteImageView: UIImageView {
    private var url: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.card
        contentMode = .scaleAspectFill
        clipsToBounds = true
        layer.cornerRadius = 6
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func set(_ url: URL?) {
        self.url = url
        image = nil
        guard let url = url else { return }
        ImageLoader.load(url) { [weak self] image in
            if self?.url == url { self?.image = image }
        }
    }
}

// MARK: - Offline library

enum Library {
    static let changed = Notification.Name("LibraryChanged")
    static let extensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "aif", "flac", "caf", "mp4"]

    static var folder: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func tracks() -> [Track] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { file in
                let name = file.deletingPathExtension().lastPathComponent
                let parts = name.components(separatedBy: " - ")
                if parts.count >= 2 {
                    return Track(title: parts.dropFirst().joined(separator: " - "), artist: parts[0], stream: file)
                }
                return Track(title: name, artist: "", stream: file)
            }
    }

    private static func freeURL(name: String, ext: String) -> URL {
        var candidate = folder.appendingPathComponent("\(name).\(ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(name) (\(n)).\(ext)")
            n += 1
        }
        return candidate
    }

    static func importFile(_ source: URL) {
        let name = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension.isEmpty ? "mp3" : source.pathExtension
        try? FileManager.default.copyItem(at: source, to: freeURL(name: name, ext: ext))
        NotificationCenter.default.post(name: changed, object: nil)
    }

    static func download(_ track: Track, done: @escaping (Bool) -> Void) {
        guard let url = track.download else { done(false); return }
        API.session.downloadTask(with: url) { temp, response, _ in
            var ok = false
            if let temp = temp, ((response as? HTTPURLResponse)?.statusCode ?? 200) < 400 {
                var ext = ((response?.suggestedFilename ?? "") as NSString).pathExtension.lowercased()
                if !extensions.contains(ext) { ext = url.pathExtension.lowercased() }
                if !extensions.contains(ext) { ext = "mp3" }
                let raw = track.artist.isEmpty ? track.title : "\(track.artist) - \(track.title)"
                let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>")
                let name = raw.components(separatedBy: illegal).joined(separator: " ")
                ok = (try? FileManager.default.moveItem(at: temp, to: freeURL(name: name, ext: ext))) != nil
            }
            DispatchQueue.main.async {
                if ok { NotificationCenter.default.post(name: changed, object: nil) }
                done(ok)
            }
        }.resume()
    }
}

extension UIViewController {
    func toast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
}
