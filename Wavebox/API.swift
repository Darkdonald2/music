import Foundation

enum APIError: LocalizedError {
    case needsJamendoKey
    case message(String)

    var errorDescription: String? {
        switch self {
        case .needsJamendoKey: return "Jamendo needs a free API key."
        case .message(let m): return m
        }
    }
}

enum API {
    typealias Done = (Result<[Item], Error>) -> Void

    static let appName = "Wavebox"

    static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 25
        c.httpAdditionalHeaders = ["User-Agent": "Wavebox/1.0 (iOS)"]
        return URLSession(configuration: c)
    }()

    static var jamendoKey: String {
        get { return UserDefaults.standard.string(forKey: "jamendoKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "jamendoKey") }
    }

    static var region: String {
        return (Locale.current.regionCode ?? "US").lowercased()
    }

    // MARK: - Plumbing

    static func url(_ base: String, _ params: [(String, String)] = []) -> URL? {
        guard var c = URLComponents(string: base) else { return nil }
        if !params.isEmpty {
            c.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        }
        return c.url
    }

    static func json(_ url: URL?, done: @escaping (Result<Any, Error>) -> Void) {
        guard let url = url else {
            done(.failure(APIError.message("Bad address.")))
            return
        }
        session.dataTask(with: url) { data, response, error in
            var result: Result<Any, Error>
            if let error = error {
                result = .failure(error)
            } else if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                result = .failure(APIError.message("Server answered \(http.statusCode)."))
            } else if let data = data, let obj = try? JSONSerialization.jsonObject(with: data, options: []) {
                result = .success(obj)
            } else {
                result = .failure(APIError.message("Could not read the server's answer."))
            }
            DispatchQueue.main.async { done(result) }
        }.resume()
    }

    private static func str(_ any: Any?) -> String? {
        if let s = any as? String { return s }
        if let n = any as? NSNumber { return n.stringValue }
        if let a = any as? [Any] { return str(a.first) }
        return nil
    }

    // MARK: - Dispatch

    static func fetch(_ source: Source, query: String, done: @escaping Done) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        switch source {
        case .popular: q.isEmpty ? popularChart(done) : popularSearch(q, done)
        case .audius: audius(q, done)
        case .jamendo: jamendo(q, done)
        case .archive: archive(q, done)
        case .radio: radio(q, done)
        case .youtube, .soundcloud: done(.success([]))
        }
    }

    // MARK: - Popular (Apple's iTunes catalogue: charts, search, 30 s previews)

    private static func itunesTracks(_ obj: Any) -> [(String, Track)] {
        guard let results = (obj as? [String: Any])?["results"] as? [[String: Any]] else { return [] }
        var out: [(String, Track)] = []
        for r in results {
            guard let name = r["trackName"] as? String else { continue }
            let art = (r["artworkUrl100"] as? String)?.replacingOccurrences(of: "100x100", with: "300x300")
            let preview = (r["previewUrl"] as? String).flatMap { URL(string: $0) }
            let t = Track(title: name,
                          artist: r["artistName"] as? String ?? "",
                          artwork: art.flatMap { URL(string: $0) },
                          stream: preview,
                          badge: "Preview")
            out.append((str(r["trackId"]) ?? "", t))
        }
        return out
    }

    private static func popularSearch(_ q: String, _ done: @escaping Done) {
        let u = url("https://itunes.apple.com/search",
                    [("term", q), ("media", "music"), ("entity", "song"), ("limit", "50"), ("country", region)])
        json(u) { result in
            done(result.map { itunesTracks($0).map { Item.track($0.1) } })
        }
    }

    private static func popularChart(_ done: @escaping Done) {
        chart(country: region) { result in
            switch result {
            case .success(let items) where !items.isEmpty:
                done(.success(items))
            default:
                // Not every country has a chart feed; fall back to the US one.
                chart(country: "us", done)
            }
        }
    }

    private static func chart(country: String, _ done: @escaping Done) {
        let feed = URL(string: "https://rss.applemarketingtools.com/api/v2/\(country)/music/most-played/50/songs.json")
        json(feed) { result in
            guard case .success(let obj) = result,
                  let entries = ((obj as? [String: Any])?["feed"] as? [String: Any])?["results"] as? [[String: Any]]
            else {
                if case .failure(let e) = result { done(.failure(e)) } else { done(.success([])) }
                return
            }
            let ids = entries.compactMap { $0["id"] as? String }
            guard !ids.isEmpty else { done(.success([])); return }
            // The chart has no audio links; look the songs up to get their previews.
            let lookup = url("https://itunes.apple.com/lookup",
                             [("id", ids.joined(separator: ",")), ("country", country), ("entity", "song")])
            json(lookup) { result in
                var byID: [String: Track] = [:]
                if case .success(let obj) = result {
                    for (id, t) in itunesTracks(obj) { byID[id] = t }
                }
                let items: [Item] = entries.map { e in
                    if let id = e["id"] as? String, let t = byID[id] { return .track(t) }
                    let art = (e["artworkUrl100"] as? String).flatMap { URL(string: $0) }
                    return .track(Track(title: e["name"] as? String ?? "",
                                        artist: e["artistName"] as? String ?? "",
                                        artwork: art))
                }
                done(.success(items))
            }
        }
    }

    // MARK: - Audius

    private static func audius(_ q: String, _ done: @escaping Done) {
        let base = "https://api.audius.co/v1/tracks"
        let u = q.isEmpty
            ? url(base + "/trending", [("app_name", appName), ("limit", "50")])
            : url(base + "/search", [("query", q), ("app_name", appName), ("limit", "50")])
        json(u) { result in
            done(result.map { obj in
                let rows = (obj as? [String: Any])?["data"] as? [[String: Any]] ?? []
                return rows.compactMap { r -> Item? in
                    guard let id = str(r["id"]), let title = r["title"] as? String else { return nil }
                    let art = r["artwork"] as? [String: Any]
                    let artURL = (art?["480x480"] as? String ?? art?["150x150"] as? String).flatMap { URL(string: $0) }
                    let stream = url(base + "/\(id)/stream", [("app_name", appName)])
                    let allowed = (r["is_downloadable"] as? Bool ?? false) || (r["downloadable"] as? Bool ?? false)
                    let user = r["user"] as? [String: Any]
                    return .track(Track(title: title,
                                        artist: user?["name"] as? String ?? "",
                                        artwork: artURL,
                                        stream: stream,
                                        download: allowed ? stream : nil))
                }
            })
        }
    }

    // MARK: - Jamendo

    private static func jamendo(_ q: String, _ done: @escaping Done) {
        guard !jamendoKey.isEmpty else { done(.failure(APIError.needsJamendoKey)); return }
        var params = [("client_id", jamendoKey), ("format", "json"), ("limit", "50"),
                      ("audioformat", "mp32"), ("imagesize", "300")]
        if q.isEmpty {
            params.append(("order", "popularity_week"))
        } else {
            params.append(("search", q))
        }
        json(url("https://api.jamendo.com/v3.0/tracks/", params)) { result in
            switch result {
            case .failure(let e): done(.failure(e))
            case .success(let obj):
                let root = obj as? [String: Any]
                let headers = root?["headers"] as? [String: Any]
                if let code = headers?["code"] as? Int, code != 0 {
                    let msg = headers?["error_message"] as? String ?? "Jamendo rejected the request."
                    if code == 5 { jamendoKey = "" }
                    done(.failure(APIError.message(msg)))
                    return
                }
                let rows = root?["results"] as? [[String: Any]] ?? []
                done(.success(rows.compactMap { r -> Item? in
                    guard let name = r["name"] as? String else { return nil }
                    let allowed = r["audiodownload_allowed"] as? Bool ?? false
                    let dl = (r["audiodownload"] as? String).flatMap { URL(string: $0) }
                    return .track(Track(title: name,
                                        artist: r["artist_name"] as? String ?? "",
                                        artwork: (r["image"] as? String).flatMap { URL(string: $0) },
                                        stream: (r["audio"] as? String).flatMap { URL(string: $0) },
                                        download: allowed ? dl : nil))
                }))
            }
        }
    }

    // MARK: - Internet Archive

    private static func archive(_ q: String, _ done: @escaping Done) {
        let query = q.isEmpty ? "mediatype:audio AND collection:etree" : "mediatype:audio AND (\(q))"
        let u = url("https://archive.org/advancedsearch.php",
                    [("q", query), ("fl[]", "identifier"), ("fl[]", "title"), ("fl[]", "creator"),
                     ("sort[]", "downloads desc"), ("rows", "50"), ("output", "json")])
        json(u) { result in
            done(result.map { obj in
                let docs = ((obj as? [String: Any])?["response"] as? [String: Any])?["docs"] as? [[String: Any]] ?? []
                return docs.compactMap { d -> Item? in
                    guard let id = d["identifier"] as? String else { return nil }
                    return .album(id: id,
                                  title: str(d["title"]) ?? id,
                                  subtitle: str(d["creator"]) ?? "Internet Archive",
                                  artwork: URL(string: "https://archive.org/services/img/\(id)"))
                }
            })
        }
    }

    static func archiveTracks(id: String, done: @escaping Done) {
        json(URL(string: "https://archive.org/metadata/\(id)")) { result in
            done(result.map { obj in
                let root = obj as? [String: Any]
                let files = root?["files"] as? [[String: Any]] ?? []
                let meta = root?["metadata"] as? [String: Any]
                let creator = str(meta?["creator"]) ?? str(meta?["title"]) ?? ""
                let art = URL(string: "https://archive.org/services/img/\(id)")
                var mp3s = files.filter { (($0["format"] as? String) ?? "") == "VBR MP3" }
                if mp3s.isEmpty {
                    mp3s = files.filter { (($0["name"] as? String) ?? "").lowercased().hasSuffix(".mp3") }
                }
                return mp3s.compactMap { f -> Item? in
                    guard let name = f["name"] as? String,
                          let path = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                          let u = URL(string: "https://archive.org/download/\(id)/\(path)") else { return nil }
                    let fallback = (name as NSString).lastPathComponent
                    return .track(Track(title: str(f["title"]) ?? (fallback as NSString).deletingPathExtension,
                                        artist: str(f["creator"]) ?? creator,
                                        artwork: art, stream: u, download: u))
                }
            })
        }
    }

    // MARK: - Radio Browser

    private static func radio(_ q: String, _ done: @escaping Done) {
        let base = "https://de1.api.radio-browser.info/json/stations"
        let u = q.isEmpty
            ? url(base + "/topclick/80", [("hidebroken", "true")])
            : url(base + "/search", [("name", q), ("limit", "80"), ("hidebroken", "true"),
                                     ("order", "clickcount"), ("reverse", "true")])
        json(u) { result in
            done(result.map { obj in
                let rows = obj as? [[String: Any]] ?? []
                return rows.compactMap { r -> Item? in
                    guard let name = r["name"] as? String else { return nil }
                    let codec = (r["codec"] as? String ?? "").uppercased()
                    // AVPlayer cannot decode Ogg/Opus streams.
                    if codec.contains("OGG") || codec.contains("OPUS") || codec.contains("FLAC") { return nil }
                    let link = (r["url_resolved"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (r["url"] as? String ?? "")
                    guard let stream = URL(string: link) else { return nil }
                    let icon = (r["favicon"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
                    let country = r["country"] as? String ?? ""
                    let tags = (r["tags"] as? String ?? "").split(separator: ",").prefix(2).joined(separator: ", ")
                    let sub = [country, tags].filter { !$0.isEmpty }.joined(separator: " · ")
                    return .track(Track(title: name.trimmingCharacters(in: .whitespaces),
                                        artist: sub, artwork: icon, stream: stream,
                                        isLive: true, badge: "Live"))
                }
            })
        }
    }
}
