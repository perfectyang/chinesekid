import AVFoundation
import Combine
import Foundation

@MainActor
final class PinyinAudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?
    private var queuePlayer: AVQueuePlayer?

    @discardableResult
    func play(_ item: PinyinUnit, rate: Float = 1.0) -> Bool {
        guard let url = resourceURL(categoryID: item.categoryID, symbol: item.symbol, tone: nil) else { return false }
        return play(url, rate: rate)
    }

    @discardableResult
    func play(_ item: PinyinUnit, tone: Int, rate: Float = 1.0) -> Bool {
        guard let url = resourceURL(categoryID: item.categoryID, symbol: item.symbol, tone: tone) else { return false }
        return play(url, rate: rate)
    }

    @discardableResult
    func playSpelling(initial: String, final: String, tone: Int) -> Bool {
        let finalCategory: String
        if ["a", "o", "e", "i", "u", "ü"].contains(final) { finalCategory = "simple" }
        else if ["ai", "ei", "ui", "ao", "ou", "iu", "ie", "üe", "er"].contains(final) { finalCategory = "compound" }
        else if ["an", "en", "in", "un", "ün"].contains(final) { finalCategory = "front_nasal" }
        else if ["ang", "eng", "ing", "ong"].contains(final) { finalCategory = "back_nasal" }
        else { return false }

        guard let finalURL = resourceURL(categoryID: finalCategory, symbol: final, tone: tone == 0 ? nil : tone) else { return false }
        var urls: [URL] = []
        if !initial.isEmpty {
            guard let initialURL = resourceURL(categoryID: "initial", symbol: initial, tone: nil) else { return false }
            urls.append(initialURL)
        }
        urls.append(finalURL)

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true)
            player?.stop()
            queuePlayer?.pause()
            let queue = AVQueuePlayer()
            urls.forEach { queue.insert(AVPlayerItem(url: $0), after: nil) }
            queuePlayer = queue
            queue.play()
            return true
        } catch {
            queuePlayer = nil
            return false
        }
    }

    @discardableResult
    func playStandaloneVowel(_ vowel: String, tone: Int, rate: Float = 1.0) -> Bool {
        guard (1...4).contains(tone) else { return false }
        let folderNames: [String]
        switch vowel {
        case "a": folderNames = ["ɑ", "a"]
        case "ü": folderNames = ["ü", "ü", "v"]
        default: folderNames = [vowel]
        }
        for folderName in folderNames {
            if let audioURL = audioFile(category: "韵母", group: "单韵母", symbol: folderName, tone: tone) {
                return play(audioURL, rate: rate)
            }
        }
        return false
    }

    private func resourceURL(categoryID: String, symbol: String, tone: Int?) -> URL? {
        let category: String
        let group: String
        switch categoryID {
        case "initial": category = "声母"; group = ""
        case "simple": category = "韵母"; group = "单韵母"
        case "compound": category = "韵母"; group = "复韵母"
        case "front_nasal": category = "韵母"; group = "前鼻韵母"
        case "back_nasal": category = "韵母"; group = "后鼻韵母"
        case "whole": category = "整体认读"; group = ""
        default: return nil
        }
        let directoryNames: [String]
        switch symbol {
        case "a", "ai", "an", "ang", "ao": directoryNames = [symbol.replacingOccurrences(of: "a", with: "ɑ", range: symbol.startIndex..<symbol.index(after: symbol.startIndex)), symbol]
        case "ü", "üe", "ün": directoryNames = [symbol.replacingOccurrences(of: "ü", with: "ü"), symbol]
        default: directoryNames = [symbol]
        }
        for directoryName in directoryNames {
            if let url = audioFile(category: category, group: group, symbol: directoryName, tone: tone) { return url }
        }
        return nil
    }

    private func audioFile(category: String, group: String, symbol: String, tone: Int?) -> URL? {
        guard let resourceRoot = Bundle.main.resourceURL else { return nil }
        let prefixes = [
            resourceRoot.appendingPathComponent("Resources", isDirectory: true),
            resourceRoot
        ]
        for prefix in prefixes {
            var directory = prefix
                .appendingPathComponent("拼音播放资源", isDirectory: true)
                .appendingPathComponent(category, isDirectory: true)
            if !group.isEmpty { directory.appendPathComponent(group, isDirectory: true) }
            directory.appendPathComponent(symbol, isDirectory: true)
            guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { continue }
            let expectedPrefix = tone.map { String(format: "%02d-", $0) }
            if let audioURL = files.first(where: { url in
                let filename = url.deletingPathExtension().lastPathComponent
                let matchesName = expectedPrefix.map { filename.hasPrefix($0) } ?? (filename == "基本读音")
                return matchesName && ["mp3", "m4a"].contains(url.pathExtension.lowercased())
            }) { return audioURL }
        }
        return nil
    }

    private func play(_ url: URL, rate: Float) -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true)

            player?.stop()
            queuePlayer?.pause()
            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.rate = min(max(rate, 0.5), 2.0)
            player?.prepareToPlay()
            return player?.play() ?? false
        } catch {
            player = nil
            return false
        }
    }
}
