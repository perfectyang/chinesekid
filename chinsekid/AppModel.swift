import AVFoundation
import Combine
import Foundation
import UIKit

enum HomeModule: String, CaseIterable, Identifiable {
    case hanziExploration
    case hanziDecomposition
    case listening
    case arithmetic
    case equationBalance
    case pinyin
    case alphabet
    case snake
    case fish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hanziExploration: "汉字探索区"
        case .hanziDecomposition: "汉字拆解"
        case .listening: "听音找字"
        case .arithmetic: "口算挑战"
        case .equationBalance: "等式平衡"
        case .pinyin: "拼音乐园"
        case .alphabet: "英文字母岛"
        case .snake: "小蛇闯关"
        case .fish: "海底大冒险"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var users: [ChildProfile] = []
    @Published private(set) var currentUser: ChildProfile
    @Published private(set) var characters: [LearningCharacter] = []
    @Published private(set) var listeningMistakes: [LearningCharacter] = []
    @Published private(set) var practiceSets: [PracticeCharacterSet] = []
    @Published private(set) var studiedPinyinItems: Set<String> = []
    @Published private(set) var studiedAlphabetLetters: Set<String> = []
    @Published private(set) var snakeRewardStatus = SnakeRewardStatus.locked
    @Published private(set) var fishTicketSettings = FishTicketSettings()
    @Published private(set) var visibleHomeModules = Set(HomeModule.allCases)
    @Published private(set) var learnedCount = 0
    @Published private(set) var dueCount = 0
    @Published var errorMessage: String?

    private var store: SQLiteStore?

    init() {
        do {
            let store = try SQLiteStore()
            self.store = store
            let profiles = try store.users()
            self.users = profiles
            self.currentUser = profiles.first ?? ChildProfile(id: "local", name: "小小探险家", avatar: "🦊")
            loadHomeModules(for: self.currentUser.id)
            loadFishTicketSettings(for: self.currentUser.id)
            refresh()
        } catch {
            self.store = nil
            self.currentUser = ChildProfile(id: "local", name: "小小探险家", avatar: "🦊")
            loadHomeModules(for: self.currentUser.id)
            loadFishTicketSettings(for: self.currentUser.id)
            self.errorMessage = error.localizedDescription
        }
    }

    func switchUser(to user: ChildProfile) {
        currentUser = user
        loadHomeModules(for: user.id)
        loadFishTicketSettings(for: user.id)
        refresh()
    }

    func saveFishTicketSettings(_ settings: FishTicketSettings) {
        fishTicketSettings = settings
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: "fish.ticketSettings.\(currentUser.id)")
    }

    func resetFishSkinUnlockProgress() {
        let defaults = UserDefaults.standard
        let prefix = "fish.skinProgress.\(currentUser.id)"
        for key in ["eaten", "bestLevel", "officialEaten", "officialBestLevel", "officialBestRunEaten"] {
            defaults.removeObject(forKey: "\(prefix).\(key)")
        }
        defaults.set(["clownfish"], forKey: "\(prefix).unlocked")
        defaults.set("clownfish", forKey: "\(prefix).selected")
    }

    private func loadFishTicketSettings(for userID: String) {
        let key = "fish.ticketSettings.\(userID)"
        if let data = UserDefaults.standard.data(forKey: key),
           let settings = try? JSONDecoder().decode(FishTicketSettings.self, from: data) {
            fishTicketSettings = settings
        } else {
            fishTicketSettings = FishTicketSettings()
        }
    }

    func isHomeModuleVisible(_ module: HomeModule) -> Bool {
        visibleHomeModules.contains(module)
    }

    func setHomeModule(_ module: HomeModule, isVisible: Bool) {
        var updated = visibleHomeModules
        if isVisible {
            updated.insert(module)
        } else {
            updated.remove(module)
        }
        guard updated != visibleHomeModules else { return }
        visibleHomeModules = updated
        UserDefaults.standard.set(
            updated.map(\.rawValue).sorted(),
            forKey: homeModulesDefaultsKey(for: currentUser.id)
        )
    }

    private func loadHomeModules(for userID: String) {
        let defaults = UserDefaults.standard
        let currentKey = homeModulesDefaultsKey(for: userID)
        if let storedModules = defaults.array(forKey: currentKey) as? [String] {
            visibleHomeModules = Set(storedModules.compactMap(HomeModule.init(rawValue:)))
            return
        }

        let previousV6Key = "home.visibleModules.v6.\(userID)"
        if let previousModules = defaults.array(forKey: previousV6Key) as? [String] {
            visibleHomeModules = Set(previousModules.compactMap(HomeModule.init(rawValue:)))
            visibleHomeModules.insert(.fish)
            defaults.set(visibleHomeModules.map(\.rawValue).sorted(), forKey: currentKey)
            return
        }

        let previousV5Key = "home.visibleModules.v5.\(userID)"
        if let previousModules = defaults.array(forKey: previousV5Key) as? [String] {
            visibleHomeModules = Set(previousModules.compactMap(HomeModule.init(rawValue:)))
            visibleHomeModules.insert(.snake)
            visibleHomeModules.insert(.fish)
            defaults.set(visibleHomeModules.map(\.rawValue).sorted(), forKey: currentKey)
            return
        }

        let previousV4Key = "home.visibleModules.v4.\(userID)"
        if let previousModules = defaults.array(forKey: previousV4Key) as? [String] {
            visibleHomeModules = Set(previousModules.compactMap(HomeModule.init(rawValue:)))
            visibleHomeModules.insert(.alphabet)
            visibleHomeModules.insert(.fish)
            defaults.set(visibleHomeModules.map(\.rawValue).sorted(), forKey: currentKey)
            return
        }

        let previousV3Key = "home.visibleModules.v3.\(userID)"
        if let previousModules = defaults.array(forKey: previousV3Key) as? [String] {
            visibleHomeModules = Set(previousModules.compactMap(HomeModule.init(rawValue:)))
            visibleHomeModules.insert(.equationBalance)
            visibleHomeModules.insert(.alphabet)
            visibleHomeModules.insert(.fish)
            defaults.set(visibleHomeModules.map(\.rawValue).sorted(), forKey: currentKey)
            return
        }

        let previousV2Key = "home.visibleModules.v2.\(userID)"
        if let previousModules = defaults.array(forKey: previousV2Key) as? [String] {
            visibleHomeModules = Set(previousModules.compactMap(HomeModule.init(rawValue:)))
            visibleHomeModules.insert(.hanziDecomposition)
            visibleHomeModules.insert(.alphabet)
            visibleHomeModules.insert(.fish)
            defaults.set(visibleHomeModules.map(\.rawValue).sorted(), forKey: currentKey)
            return
        }

        let previousKey = "home.visibleModules.v1.\(userID)"
        if let previousModules = defaults.array(forKey: previousKey) as? [String] {
            visibleHomeModules = Set(previousModules.compactMap(HomeModule.init(rawValue:)))
            visibleHomeModules.insert(.hanziExploration)
            visibleHomeModules.insert(.hanziDecomposition)
            visibleHomeModules.insert(.alphabet)
            visibleHomeModules.insert(.fish)
            defaults.set(visibleHomeModules.map(\.rawValue).sorted(), forKey: currentKey)
            return
        }

        visibleHomeModules = Set(HomeModule.allCases)
    }

    private func homeModulesDefaultsKey(for userID: String) -> String {
        "home.visibleModules.v7.\(userID)"
    }

    func addUser(named rawName: String) {
        guard let store else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            let user = try store.addUser(name: String(name.prefix(12)))
            users = try store.users()
            currentUser = user
            loadHomeModules(for: user.id)
            loadFishTicketSettings(for: user.id)
            refresh()
        } catch { report(error) }
    }

    @discardableResult
    func renameUser(_ user: ChildProfile, named rawName: String) -> Bool {
        guard let store, users.contains(where: { $0.id == user.id }) else { return false }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        do {
            try store.renameUser(id: user.id, name: String(name.prefix(12)))
            users = try store.users()
            if currentUser.id == user.id,
               let renamedUser = users.first(where: { $0.id == user.id }) {
                currentUser = renamedUser
            }
            return true
        } catch {
            report(error)
            return false
        }
    }

    func updateAvatar(for user: ChildProfile, image: UIImage) {
        guard let store, users.contains(where: { $0.id == user.id }) else { return }
        do {
            let filename = try ProfileAvatarStore.save(image, for: user.id)
            try store.setAvatarFilename(filename, forUserID: user.id)
            users = try store.users()
            if currentUser.id == user.id, let updated = users.first(where: { $0.id == user.id }) {
                currentUser = updated
            }
        } catch { report(error) }
    }

    @discardableResult
    func deleteUser(_ user: ChildProfile) -> Bool {
        guard let store, users.count > 1,
              users.contains(where: { $0.id == user.id }) else { return false }
        do {
            try store.deleteUser(id: user.id)
            UserDefaults.standard.removeObject(forKey: "fish.ticketSettings.\(user.id)")
            ProfileAvatarStore.remove(filename: user.avatarFilename)
            users = try store.users()
            if currentUser.id == user.id, let replacement = users.first {
                currentUser = replacement
                loadHomeModules(for: replacement.id)
                loadFishTicketSettings(for: replacement.id)
            }
            refresh()
            return true
        } catch {
            report(error)
            return false
        }
    }

    func importCharacters(_ glyphs: [String]) -> (added: Int, existing: Int) {
        guard let store else { return (0, 0) }
        do {
            let result = try store.importCharacters(glyphs, for: currentUser.id)
            refresh()
            return result
        } catch {
            report(error)
            return (0, 0)
        }
    }

    func makeStudySet(startingWith glyph: String? = nil, visibleOrder: [String] = []) -> [LearningCharacter] {
        guard let store else { return [] }
        do {
            if !visibleOrder.isEmpty {
                let storedCharacters = try store.characters(for: currentUser.id)
                let charactersByGlyph = Dictionary(uniqueKeysWithValues: storedCharacters.map { ($0.glyph, $0) })
                var orderedCharacters = visibleOrder.compactMap { charactersByGlyph[$0] }
                if let glyph {
                    if let selectedIndex = orderedCharacters.firstIndex(where: { $0.glyph == glyph }) {
                        orderedCharacters = Array(orderedCharacters[selectedIndex...]) + Array(orderedCharacters[..<selectedIndex])
                    } else if let selectedCharacter = charactersByGlyph[glyph] {
                        orderedCharacters.insert(selectedCharacter, at: 0)
                    }
                }
                return orderedCharacters
            }

            var cards = try store.studySet(for: currentUser.id)
            if let glyph,
               let selectedCharacter = try store.characters(for: currentUser.id).first(where: { $0.glyph == glyph }) {
                cards.removeAll { $0.glyph == glyph }
                cards.insert(selectedCharacter, at: 0)
            }
            return cards
        }
        catch { report(error); return [] }
    }

    func recordAnswer(for character: LearningCharacter, knew: Bool) {
        guard let store else { return }
        do {
            try store.recordAnswer(userID: currentUser.id, glyph: character.glyph, knew: knew)
            refresh()
        } catch { report(error) }
    }

    func recordListeningAnswer(target: String, answer: String, correct: Bool) {
        guard let store else { return }
        do {
            try store.recordListeningAnswer(
                userID: currentUser.id,
                targetGlyph: target,
                answerGlyph: answer,
                correct: correct
            )
            refresh()
        } catch { report(error) }
    }

    @discardableResult
    func savePracticeSet(id: String? = nil, name rawName: String, glyphs: [String]) -> String? {
        guard let store else { return nil }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let availableGlyphs = Set(characters.map(\.glyph))
        let selectedGlyphs = Array(Set(glyphs.filter { availableGlyphs.contains($0) }))
        guard !name.isEmpty, !selectedGlyphs.isEmpty else { return nil }
        do {
            let savedID = try store.savePracticeSet(
                id: id,
                name: String(name.prefix(24)),
                glyphs: selectedGlyphs,
                userID: currentUser.id
            )
            refresh()
            return savedID
        } catch {
            report(error)
            return nil
        }
    }

    func deletePracticeSet(_ set: PracticeCharacterSet) {
        guard let store else { return }
        do {
            try store.deletePracticeSet(id: set.id, userID: currentUser.id)
            refresh()
        } catch { report(error) }
    }

    func contains(_ glyph: String) -> Bool {
        characters.contains { $0.glyph == glyph }
    }

    func recordPinyinStudy(itemID: String) {
        guard let store else { return }
        do {
            try store.recordPinyinStudy(userID: currentUser.id, itemID: itemID)
            studiedPinyinItems.insert(itemID)
        } catch { report(error) }
    }

    func recordAlphabetStudy(letter: String) {
        guard let store else { return }
        do {
            try store.recordAlphabetStudy(userID: currentUser.id, letter: letter)
            studiedAlphabetLetters.insert(letter.uppercased())
        } catch { report(error) }
    }

    func startAlphabetSnakePracticeRound() {
        guard let store else { return }
        do {
            snakeRewardStatus = try store.resetAlphabetSnakePracticeProgress(userID: currentUser.id)
        } catch { report(error) }
    }

    @discardableResult
    func recordAlphabetSnakePracticeAnswer(isCorrect: Bool) -> SnakeRewardStatus {
        guard let store else { return snakeRewardStatus }
        do {
            snakeRewardStatus = try store.recordAlphabetSnakePracticeAnswer(userID: currentUser.id, isCorrect: isCorrect)
            return snakeRewardStatus
        } catch { report(error) }
        return snakeRewardStatus
    }

    @discardableResult
    func spendSnakeTicket(count: Int = 1) -> Bool {
        guard let store else { return false }
        do {
            let spent = try store.consumeSnakeTicket(userID: currentUser.id, count: count)
            refreshSnakeRewardStatus()
            return spent
        } catch {
            report(error)
            return false
        }
    }

    @discardableResult
    func awardFishPracticeTicket(roundID: String) -> Bool {
        guard let store else { return false }
        do {
            let awarded = try store.awardFishPracticeTicket(userID: currentUser.id, roundID: roundID)
            refreshSnakeRewardStatus()
            return awarded
        } catch {
            report(error)
            return false
        }
    }

    private func refresh() {
        guard let store else { return }
        do {
            characters = try store.characters(for: currentUser.id)
            listeningMistakes = try store.listeningMistakes(for: currentUser.id)
            practiceSets = try store.practiceSets(for: currentUser.id)
            studiedPinyinItems = try store.studiedPinyinItems(for: currentUser.id)
            studiedAlphabetLetters = try store.studiedAlphabetLetters(for: currentUser.id)
            snakeRewardStatus = try store.snakeRewardStatus(for: currentUser.id)
            let progress = try store.progress(for: currentUser.id)
            learnedCount = progress.learned
            dueCount = progress.due
        } catch { report(error) }
    }

    func refreshSnakeRewardStatus() {
        guard let store else {
            snakeRewardStatus = .locked
            return
        }
        do {
            snakeRewardStatus = try store.snakeRewardStatus(for: currentUser.id)
        } catch { report(error) }
    }

    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

@MainActor
final class SpeechPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()
    private var utteranceQueue: [AVSpeechUtterance] = []
    private var activeUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        speak(text, language: "zh-CN")
    }

    func speakEncouragement() {
        speak("你真棒", language: "zh-CN")
    }

    private func speak(_ text: String, language: String) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            NSLog("Speech audio session setup failed: %@", error.localizedDescription)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: language)
        // A slightly slower pace gives children time to hear the tone without
        // stretching the syllable as much as the earlier fixed rate did.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.03
        utterance.preUtteranceDelay = 0.06
        utterance.postUtteranceDelay = 0.12
        utteranceQueue.append(utterance)
        startNextUtteranceIfNeeded()
    }

    private func startNextUtteranceIfNeeded() {
        guard activeUtterance == nil, !utteranceQueue.isEmpty else { return }
        let utterance = utteranceQueue.removeFirst()
        activeUtterance = utterance
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finishUtterance(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finishUtterance(utterance)
    }

    private func finishUtterance(_ utterance: AVSpeechUtterance) {
        guard activeUtterance === utterance else { return }
        activeUtterance = nil
        isSpeaking = false
        startNextUtteranceIfNeeded()
    }

    func stop() {
        utteranceQueue.removeAll()
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private func voice(for language: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language }
            .sorted { qualityRank($0.quality) > qualityRank($1.quality) }
        return voices.first ?? AVSpeechSynthesisVoice(language: language)
    }

    private func qualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: 3
        case .enhanced: 2
        default: 1
        }
    }
}
