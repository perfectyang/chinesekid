import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var users: [ChildProfile] = []
    @Published private(set) var currentUser: ChildProfile
    @Published private(set) var characters: [LearningCharacter] = []
    @Published private(set) var listeningMistakes: [LearningCharacter] = []
    @Published private(set) var practiceSets: [PracticeCharacterSet] = []
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
            refresh()
        } catch {
            self.store = nil
            self.currentUser = ChildProfile(id: "local", name: "小小探险家", avatar: "🦊")
            self.errorMessage = error.localizedDescription
        }
    }

    func switchUser(to user: ChildProfile) {
        currentUser = user
        refresh()
    }

    func addUser(named rawName: String) {
        guard let store else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            let user = try store.addUser(name: String(name.prefix(12)))
            users = try store.users()
            currentUser = user
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
            ProfileAvatarStore.remove(filename: user.avatarFilename)
            users = try store.users()
            if currentUser.id == user.id, let replacement = users.first {
                currentUser = replacement
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

    private func refresh() {
        guard let store else { return }
        do {
            characters = try store.characters(for: currentUser.id)
            listeningMistakes = try store.listeningMistakes(for: currentUser.id)
            practiceSets = try store.practiceSets(for: currentUser.id)
            let progress = try store.progress(for: currentUser.id)
            learnedCount = progress.learned
            dueCount = progress.due
        } catch { report(error) }
    }

    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

@MainActor
final class SpeechPlayer: ObservableObject {
    @Published private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()
    private var playbackID = UUID()
    private var pendingSpeech: DispatchWorkItem?

    func speak(_ text: String) {
        speak(text, language: "zh-CN")
    }

    func speakEncouragement() {
        speak("你真棒", language: "zh-CN")
    }

    private func speak(_ text: String, language: String) {
        pendingSpeech?.cancel()
        pendingSpeech = nil
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: language)
        // A slightly slower pace gives children time to hear the tone without
        // stretching the syllable as much as the earlier fixed rate did.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.03
        utterance.preUtteranceDelay = 0.06
        utterance.postUtteranceDelay = 0.12
        let playbackID = UUID()
        self.playbackID = playbackID
        isSpeaking = true
        scheduleStart(utterance, text: text, playbackID: playbackID, after: 0.12)
    }

    private func scheduleStart(
        _ utterance: AVSpeechUtterance,
        text: String,
        playbackID: UUID,
        after delay: TimeInterval
    ) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.playbackID == playbackID else { return }
            self.pendingSpeech = nil

            // AVSpeechSynthesizer may still be finishing an immediate stop.
            // Wait until it is ready before submitting the latest tap.
            if self.synthesizer.isSpeaking || self.synthesizer.isPaused {
                self.synthesizer.stopSpeaking(at: .immediate)
                self.scheduleStart(utterance, text: text, playbackID: playbackID, after: 0.08)
                return
            }

            self.synthesizer.speak(utterance)
            let duration = max(0.9, Double(text.count) * 0.65)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self, self.playbackID == playbackID else { return }
                self.isSpeaking = false
            }
        }
        pendingSpeech = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func stop() {
        playbackID = UUID()
        pendingSpeech?.cancel()
        pendingSpeech = nil
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
