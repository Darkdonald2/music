import AVFoundation
import MediaPlayer
import UIKit

final class AudioPlayer: NSObject {
    static let shared = AudioPlayer()
    static let changed = Notification.Name("AudioPlayerChanged")
    static let ticked = Notification.Name("AudioPlayerTicked")

    private let player = AVPlayer()
    private(set) var queue: [Track] = []
    private(set) var index = 0
    private var artwork: UIImage?
    private var statusObservation: NSKeyValueObservation?

    var current: Track? { return queue.indices.contains(index) ? queue[index] : nil }
    var isPlaying: Bool { return player.timeControlStatus != .paused }

    var elapsed: Double {
        let t = player.currentTime().seconds
        return t.isFinite ? max(t, 0) : 0
    }

    var duration: Double {
        guard let d = player.currentItem?.duration.seconds, d.isFinite else { return 0 }
        return d
    }

    private override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)

        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { _ in
            NotificationCenter.default.post(name: AudioPlayer.ticked, object: nil)
        }
        statusObservation = player.observe(\.timeControlStatus) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateNowPlaying()
                NotificationCenter.default.post(name: AudioPlayer.changed, object: nil)
            }
        }

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(itemEnded(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        nc.addObserver(self, selector: #selector(itemEnded(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        nc.addObserver(self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)

        let rc = MPRemoteCommandCenter.shared()
        rc.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        rc.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        rc.togglePlayPauseCommand.addTarget { [weak self] _ in self?.toggle(); return .success }
        rc.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        rc.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
        rc.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent { self?.seek(to: e.positionTime) }
            return .success
        }
    }

    // MARK: - Controls

    func play(_ tracks: [Track], at i: Int) {
        queue = tracks
        index = i
        load()
    }

    func toggle() {
        if isPlaying { pause() } else { resume() }
    }

    func pause() {
        player.pause()
    }

    func resume() {
        guard current != nil else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
    }

    func next() {
        guard index + 1 < queue.count else {
            player.pause()
            return
        }
        index += 1
        load()
    }

    func previous() {
        if elapsed > 4 || index == 0 {
            seek(to: 0)
        } else {
            index -= 1
            load()
        }
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600)) { [weak self] _ in
            DispatchQueue.main.async { self?.updateNowPlaying() }
        }
    }

    // MARK: - Internals

    private func load() {
        guard let track = current, let url = track.stream else { return }
        artwork = nil
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        if let art = track.artwork {
            ImageLoader.load(art) { [weak self] image in
                guard let self = self, self.current?.artwork == art else { return }
                self.artwork = image
                self.updateNowPlaying()
            }
        }
        updateNowPlaying()
        NotificationCenter.default.post(name: AudioPlayer.changed, object: nil)
    }

    @objc private func itemEnded(_ note: Notification) {
        guard let item = note.object as? AVPlayerItem, item === player.currentItem else { return }
        DispatchQueue.main.async { self.next() }
    }

    @objc private func interrupted(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended,
           let optRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
           AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume) {
            resume()
        }
    }

    private func updateNowPlaying() {
        guard let track = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: track.isLive
        ]
        if !track.isLive && duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let image = artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
