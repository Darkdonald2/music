import Foundation

enum Source: Int, CaseIterable {
    case popular, audius, jamendo, archive, radio, youtube, soundcloud

    var title: String {
        switch self {
        case .popular: return "Popular"
        case .audius: return "Audius"
        case .jamendo: return "Jamendo"
        case .archive: return "Archive"
        case .radio: return "Radio"
        case .youtube: return "YouTube"
        case .soundcloud: return "SoundCloud"
        }
    }

    /// Sources that open the official website inside the app instead of native playback.
    var isWeb: Bool { return self == .youtube || self == .soundcloud }

    func webURL(query: String) -> URL? {
        let q = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        switch self {
        case .youtube:
            return URL(string: q.isEmpty ? "https://m.youtube.com/" : "https://m.youtube.com/results?search_query=\(q)")
        case .soundcloud:
            return URL(string: q.isEmpty ? "https://m.soundcloud.com/" : "https://m.soundcloud.com/search?q=\(q)")
        default:
            return nil
        }
    }
}

struct Track {
    var title: String
    var artist: String
    var artwork: URL?
    var stream: URL?
    var download: URL?
    var isLive = false
    var badge: String?

    init(title: String, artist: String, artwork: URL? = nil, stream: URL? = nil,
         download: URL? = nil, isLive: Bool = false, badge: String? = nil) {
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.stream = stream
        self.download = download
        self.isLive = isLive
        self.badge = badge
    }
}

enum Item {
    case track(Track)
    case album(id: String, title: String, subtitle: String, artwork: URL?)
}
