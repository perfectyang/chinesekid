import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import Vision

struct EnglishWordDictationItem: Codable, Identifiable {
    var id: String
    var word: String
    var audioFilename: String
}

struct EnglishWordDictationAttempt: Codable, Identifiable {
    var id: String
    var date: Date
    var correct: Int
    var total: Int
}

struct EnglishWordDictation: Codable, Identifiable {
    var id: String
    var userID: String
    var name: String
    var createdAt: Date
    var items: [EnglishWordDictationItem]
    var attempts: [EnglishWordDictationAttempt]
}

@MainActor
final class EnglishWordDictationStore {
    private let root: URL
    private let userID: String

    init(userID: String) throws {
        self.userID = userID
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        root = support.appendingPathComponent("EnglishWordDictations", isDirectory: true).appendingPathComponent(Self.safe(userID), isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func all() -> [EnglishWordDictation] {
        guard let folders = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        return folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("worksheet.json")),
                  let worksheet = try? JSONDecoder().decode(EnglishWordDictation.self, from: data) else { return nil }
            return worksheet
        }.sorted { $0.createdAt > $1.createdAt }
    }

    func audioURL(worksheetID: String, filename: String) -> URL {
        root.appendingPathComponent(Self.safe(worksheetID), isDirectory: true).appendingPathComponent(filename)
    }

    func saveDraft(id: String, name: String, words: [String], audioURLs: [URL]) throws {
        let folder = root.appendingPathComponent(Self.safe(id), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var items: [EnglishWordDictationItem] = []
        for (index, word) in words.enumerated() {
            let filename = "item-\(index).m4a"
            let destination = folder.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.copyItem(at: audioURLs[index], to: destination)
            items.append(EnglishWordDictationItem(id: UUID().uuidString, word: word, audioFilename: filename))
        }
        let worksheet = EnglishWordDictation(id: id, userID: userID, name: name, createdAt: Date(), items: items, attempts: [])
        try write(worksheet, in: folder)
    }

    func update(_ existing: EnglishWordDictation, name: String, words: [String], audioURLs: [URL]) throws {
        let folder = root.appendingPathComponent(Self.safe(existing.id), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let changed = existing.items.map(\.word) != words || existing.items.count != audioURLs.count || existing.items.enumerated().contains { index, item in
            guard audioURLs.indices.contains(index) else { return true }
            return audioURLs[index].standardizedFileURL != folder.appendingPathComponent(item.audioFilename).standardizedFileURL
        }
        var items: [EnglishWordDictationItem] = []
        for (index, word) in words.enumerated() {
            let filename = "item-\(index).m4a"
            let destination = folder.appendingPathComponent(filename)
            let source = audioURLs[index]
            if source.standardizedFileURL != destination.standardizedFileURL {
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.copyItem(at: source, to: destination)
            }
            let old = existing.items.indices.contains(index) ? existing.items[index] : nil
            let preservedID: String
            if let old, old.word == word { preservedID = old.id }
            else { preservedID = UUID().uuidString }
            items.append(EnglishWordDictationItem(id: preservedID, word: word, audioFilename: filename))
        }
        let keepFiles = Set(items.map(\.audioFilename))
        for item in existing.items where !keepFiles.contains(item.audioFilename) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(item.audioFilename))
        }
        let updated = EnglishWordDictation(
            id: existing.id, userID: userID, name: name, createdAt: existing.createdAt,
            items: items, attempts: changed ? [] : existing.attempts
        )
        try write(updated, in: folder)
    }

    func delete(_ worksheet: EnglishWordDictation) throws {
        let folder = root.appendingPathComponent(Self.safe(worksheet.id), isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    }

    func save(_ worksheet: EnglishWordDictation) throws {
        let folder = root.appendingPathComponent(Self.safe(worksheet.id), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try write(worksheet, in: folder)
    }

    private func write(_ worksheet: EnglishWordDictation, in folder: URL) throws {
        try JSONEncoder().encode(worksheet).write(to: folder.appendingPathComponent("worksheet.json"), options: .atomic)
    }

    private static func safe(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "..", with: "_")
    }
}

struct EnglishWordDictationScreen: View {
    let app: AppModel
    @State private var worksheets: [EnglishWordDictation] = []
    @State private var showingEditor = false
    @State private var editingID: String?
    @State private var deleting: EnglishWordDictation?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("英语单词听写").font(.system(size: 27, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink)
                    Text("录下每个单词的读音，听录音拼写，错词再练。").font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(KidsTheme.muted)
                }
                Button { editingID = nil; showingEditor = true } label: {
                    Label("新建英语听写单", systemImage: "plus.circle.fill")
                        .font(.system(size: 19, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 58).background(KidsTheme.yellow, in: Capsule())
                }.buttonStyle(.plain)

                if worksheets.isEmpty {
                    ContentUnavailableView("还没有英语听写单", systemImage: "text.book.closed", description: Text("新建一份听写单，添加单词并录制读音。"))
                } else {
                    ForEach(worksheets) { worksheet in
                        NavigationLink {
                            EnglishWordPracticeScreen(worksheet: worksheet, app: app) { reload() }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(worksheet.name).font(.system(size: 19, weight: .black, design: .rounded))
                                    Spacer()
                                    Image(systemName: "play.circle.fill").font(.system(size: 26))
                                }
                                HStack(spacing: 6) {
                                    Text("\(worksheet.items.count) 个单词")
                                    Text("·")
                                    Text(worksheet.attempts.isEmpty ? "还没练习" : "已练 \(worksheet.attempts.count) 次")
                                    if let latest = worksheet.attempts.last { Text("· 最近 \(latest.correct)/\(latest.total)") }
                                    Spacer()
                                    Button { editingID = worksheet.id; showingEditor = true } label: { Image(systemName: "pencil").padding(8).contentShape(Rectangle()) }
                                        .buttonStyle(.plain).accessibilityLabel("编辑听写单")
                                    Button(role: .destructive) { deleting = worksheet } label: { Image(systemName: "trash").padding(8).contentShape(Rectangle()) }
                                        .buttonStyle(.plain).accessibilityLabel("删除听写单")
                                }.font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(KidsTheme.muted)
                            }
                            .foregroundStyle(KidsTheme.ink).padding(16).background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 22))
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }
        .background { StorybookBackground() }
        .navigationTitle("英语单词听写")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingEditor) {
            EnglishWordDictationEditorScreen(app: app, existing: worksheets.first(where: { $0.id == editingID })) { reload() }
        }
        .confirmationDialog("删除这份英语听写单？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除听写单", role: .destructive) {
                guard let deleting else { return }
                do { try EnglishWordDictationStore(userID: app.currentUser.id).delete(deleting); reload() }
                catch { errorMessage = "删除失败，请稍后再试。" }
                self.deleting = nil
            }
            Button("取消", role: .cancel) { deleting = nil }
        }
        .alert("英语听写单", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onAppear(perform: reload)
    }

    private func reload() { worksheets = (try? EnglishWordDictationStore(userID: app.currentUser.id).all()) ?? [] }
}

private struct EnglishWordDictationEditorScreen: View {
    let app: AppModel
    let existing: EnglishWordDictation?
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedIndex: Int?
    @State private var name: String
    @State private var words: [String]
    @State private var audioFiles: [URL?]
    @State private var draftID: String
    @State private var activeRecorder: AVAudioRecorder?
    @State private var recordingIndex: Int?
    @State private var recordingStartedAt: Date?
    @State private var player: AVAudioPlayer?
    @State private var notice: String?
    @State private var loadedExistingAudio = false
    @State private var recordingPermission = true
    @State private var photo: PhotosPickerItem?
    @State private var cameraImage: UIImage?
    @State private var showingCamera = false
    @State private var isRecognizing = false

    init(app: AppModel, existing: EnglishWordDictation?, onSaved: @escaping () -> Void) {
        self.app = app
        self.existing = existing
        self.onSaved = onSaved
        _name = State(initialValue: existing?.name ?? "英语单词听写")
        _words = State(initialValue: existing?.items.map(\.word) ?? [""])
        _audioFiles = State(initialValue: Array(repeating: nil, count: existing?.items.count ?? 1))
        _draftID = State(initialValue: existing?.id ?? UUID().uuidString)
        _loadedExistingAudio = State(initialValue: existing == nil)
    }

    private var allRecorded: Bool { !words.isEmpty && words.count == audioFiles.count && audioFiles.allSatisfy { $0 != nil } && loadedExistingAudio }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 13) {
                    Text(existing == nil ? "给听写单起个名字，添加单词并录下读音。" : "可以修改名称、单词、录音，也可以增删单词；内容变化后会清除旧成绩。")
                        .font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(KidsTheme.muted)
                    TextField("听写单名称", text: $name).font(.system(size: 18, weight: .bold, design: .rounded)).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15))
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $photo, matching: .images) {
                            Label("从相册选照片", systemImage: "photo")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(KidsTheme.mint, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Button {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) { showingCamera = true }
                            else { notice = "当前设备没有可用的相机，可以从相册选择照片。" }
                        } label: {
                            Label("拍照识别", systemImage: "camera.fill")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(KidsTheme.yellow, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Text("照片中识别到的英文单词会添加到列表，检查后再录制每个单词的读音。")
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(KidsTheme.muted)
                    if isRecognizing { ProgressView("正在识别英文单词…").frame(maxWidth: .infinity) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(words.indices, id: \.self) { index in
                            VStack(spacing: 10) {
                                HStack(spacing: 9) {
                                    Text("\(index + 1)").font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.muted)
                                    TextField("英文单词", text: $words[index])
                                        .font(.system(size: 23, weight: .black, design: .rounded))
                                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
                                        .focused($focusedIndex, equals: index).submitLabel(.done).onSubmit { focusedIndex = nil }
                                        .onChange(of: words[index]) { oldValue, newValue in
                                            let cleaned = newValue.filter { $0.isASCII && ($0.isLetter || $0 == "'" || $0 == "-") }.lowercased()
                                            if cleaned != newValue { words[index] = cleaned; return }
                                            if oldValue != newValue { audioFiles[index] = nil }
                                        }
                                    Spacer(minLength: 0)
                                    if audioFiles[index] != nil { Button { play(index) } label: { Image(systemName: "play.circle.fill") }.font(.system(size: 26)) }
                                    Button { Task { await toggleRecording(index) } } label: {
                                        Label(recordingIndex == index ? "停止" : (audioFiles[index] == nil ? "录音" : "重录"), systemImage: recordingIndex == index ? "stop.circle.fill" : "mic.circle.fill")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                    }.tint(recordingIndex == index ? .red : KidsTheme.ink)
                                    Button(role: .destructive) { guard recordingIndex != index else { return }; words.remove(at: index); audioFiles.remove(at: index) } label: { Image(systemName: "minus.circle") }
                                        .disabled(recordingIndex != nil)
                                }
                            }
                            .foregroundStyle(KidsTheme.ink).padding(13).background(.white, in: RoundedRectangle(cornerRadius: 17))
                        }
                        Button { words.append(""); audioFiles.append(nil) } label: {
                            Label("添加一个单词", systemImage: "plus.circle.fill").font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: min(360, max(160, geometry.size.height * 0.46)))
                .scrollDismissesKeyboard(.interactively)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 9) {
                    if let notice {
                        Text(notice).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(KidsTheme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 9).frame(maxWidth: .infinity, alignment: .leading)
                            .background(KidsTheme.yellow.opacity(0.6), in: RoundedRectangle(cornerRadius: 13))
                    }
                    Button(action: save) {
                        Label(existing == nil ? "保存听写单" : "保存修改", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 54).background(KidsTheme.mint, in: Capsule())
                    }
                    .buttonStyle(.plain).disabled(!allRecorded || !validWords || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || recordingIndex != nil)
                    .opacity(allRecorded && validWords && recordingIndex == nil ? 1 : 0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .background(StorybookBackground())
            }
        }
        .background { StorybookBackground() }
        .navigationTitle(existing == nil ? "新建英语听写单" : "编辑英语听写单")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDismissToolbar { focusedIndex = nil }
        .onAppear(perform: loadExistingAudio)
        .onChange(of: photo) { _, selected in
            guard let selected else { return }
            Task {
                do {
                    if let data = try await selected.loadTransferable(type: Data.self) { await recognize(data) }
                    else { notice = "无法读取这张照片，请重新选择。" }
                } catch { notice = "照片读取失败，请重新选择。" }
                photo = nil
            }
        }
        .sheet(isPresented: $showingCamera) {
            EnglishWordDictationCameraPicker(image: $cameraImage).ignoresSafeArea()
        }
        .onChange(of: cameraImage) { _, image in
            guard let image, let data = image.jpegData(compressionQuality: 0.95) else { return }
            Task { await recognize(data) }
        }
        .onDisappear { if recordingIndex != nil { finishRecording() } }
    }

    private var validWords: Bool {
        !words.isEmpty && words.allSatisfy { !$0.isEmpty && $0.contains(where: \.isLetter) }
    }

    @MainActor
    private func recognize(_ data: Data) async {
        isRecognizing = true
        notice = nil
        defer { isRecognizing = false }
        do {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(data: data, options: [:]).perform([request])
            let observations = (request.results ?? []).sorted {
                let yDelta = abs($0.boundingBox.midY - $1.boundingBox.midY)
                return yDelta > 0.018 ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
            }
            let expression = try NSRegularExpression(pattern: "[A-Za-z]+(?:['’][A-Za-z]+|-[A-Za-z]+)*")
            var found: [String] = []
            for observation in observations {
                guard let text = observation.topCandidates(1).first?.string else { continue }
                let source = text as NSString
                for match in expression.matches(in: text, range: NSRange(location: 0, length: source.length)) {
                    let word = source.substring(with: match.range).replacingOccurrences(of: "’", with: "'").lowercased()
                    if !found.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) { found.append(word) }
                }
            }
            let existingWords = words.filter { !$0.isEmpty }
            let additions = found.filter { candidate in
                !existingWords.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame })
            }
            guard !additions.isEmpty else {
                notice = found.isEmpty ? "没有识别到英文单词。请拍清楚一些，或调整照片后重试。" : "识别到的单词已在列表中，没有重复添加。"
                return
            }
            if existingWords.isEmpty {
                words = additions
                audioFiles = Array(repeating: nil, count: additions.count)
            } else {
                words.append(contentsOf: additions)
                audioFiles.append(contentsOf: Array(repeating: nil, count: additions.count))
            }
            focusedIndex = nil
            notice = "识别并添加了 \(additions.count) 个单词，请检查拼写并录制读音。"
        } catch { notice = "识别失败，请重新拍摄或从相册选择照片。" }
    }

    private func toggleRecording(_ index: Int) async {
        if recordingIndex == index { finishRecording(); return }
        if recordingIndex != nil { finishRecording() }
        guard recordingPermission else { notice = "请在系统设置中允许使用麦克风后再录音。"; return }
        let session = AVAudioSession.sharedInstance()
        do {
            let granted = await withCheckedContinuation { continuation in session.requestRecordPermission { continuation.resume(returning: $0) } }
            guard granted else { recordingPermission = false; notice = "请允许使用麦克风来录制单词。"; return }
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("EnglishWordDictation-\(draftID)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("item-\(index).m4a")
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            guard recorder.prepareToRecord(), recorder.record() else { notice = "录音没有启动，请检查麦克风权限或重试。"; return }
            activeRecorder = recorder
            recordingIndex = index
            recordingStartedAt = Date()
            focusedIndex = nil
            notice = "请清楚地读出：\(words[index])"
        } catch { notice = "无法开始录音，请检查麦克风权限。" }
    }

    private func finishRecording() {
        guard let recorder = activeRecorder, let index = recordingIndex else { return }
        let elapsed = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        recorder.stop()
        let url = recorder.url
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if elapsed <= 0.25 { notice = "录音太短了，请再录一次。" }
        else if fileSize <= 512 { notice = "没有收到有效录音，请检查麦克风权限或输入设备。" }
        else { audioFiles[index] = url; notice = "录音已保存，可以试听或重录。" }
        activeRecorder = nil
        recordingIndex = nil
        recordingStartedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func play(_ index: Int) {
        guard let url = audioFiles[index] else { return }
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio); player = try AVAudioPlayer(contentsOf: url); player?.play() }
        catch { notice = "录音播放失败，可以重新录制。" }
    }

    private func loadExistingAudio() {
        guard let existing, !loadedExistingAudio else { return }
        do {
            let store = try EnglishWordDictationStore(userID: app.currentUser.id)
            audioFiles = existing.items.map { item in
                let url = store.audioURL(worksheetID: existing.id, filename: item.audioFilename)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
            loadedExistingAudio = true
        } catch { notice = "无法读取这份听写单的录音，请稍后再试。" }
    }

    private func save() {
        let cleanName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        let cleanWords = words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let urls = audioFiles.compactMap { $0 }
        guard !cleanName.isEmpty, validWords, allRecorded, urls.count == cleanWords.count else { return }
        do {
            let store = try EnglishWordDictationStore(userID: app.currentUser.id)
            if let existing { try store.update(existing, name: cleanName, words: cleanWords, audioURLs: urls) }
            else { try store.saveDraft(id: draftID, name: cleanName, words: cleanWords, audioURLs: urls) }
            try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appendingPathComponent("EnglishWordDictation-\(draftID)", isDirectory: true))
            onSaved()
            dismiss()
        } catch { notice = "保存失败，请检查设备存储空间后重试。" }
    }
}

private struct EnglishWordDictationCameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: EnglishWordDictationCameraPicker
        init(parent: EnglishWordDictationCameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

private struct EnglishWordPracticeScreen: View {
    let worksheet: EnglishWordDictation
    let app: AppModel
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var answerFocused: Bool
    @State private var questions: [EnglishWordDictationItem] = []
    @State private var index = 0
    @State private var answer = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var result: Int?
    @State private var firstRoundCorrect = 0
    @State private var isReviewRound = false
    @State private var roundWrongItems: [EnglishWordDictationItem] = []
    @State private var finalWrongItems: [EnglishWordDictationItem] = []
    @State private var errorMessage: String?
    @State private var didSave = false

    private var current: EnglishWordDictationItem? { questions.indices.contains(index) ? questions[index] : nil }
    private var normalizedAnswer: String { answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    var body: some View {
        Group {
            if result != nil { resultView }
            else if let current { questionView(current) }
            else { ContentUnavailableView("这份听写单没有题目", systemImage: "questionmark.folder") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StorybookBackground() }
        .navigationTitle(worksheet.name)
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDismissToolbar { answerFocused = false }
        .onAppear { if questions.isEmpty { startRound() } }
        .alert("英语听写", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func questionView(_ item: EnglishWordDictationItem) -> some View {
        VStack(spacing: 20) {
            HStack { Text(isReviewRound ? "错词复习 · 第 \(index + 1) / \(questions.count) 题" : "第 \(index + 1) / \(questions.count) 题"); Spacer(); Text(worksheet.name) }
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(KidsTheme.muted)
            ProgressView(value: Double(index + 1), total: Double(max(questions.count, 1))).tint(KidsTheme.orange)
            Text("听录音，写出英文单词。")
                .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(KidsTheme.muted)
            Button { play(item) } label: {
                VStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 42, weight: .bold))
                    Text("播放录音").font(.system(size: 21, weight: .black, design: .rounded))
                }.foregroundStyle(KidsTheme.ink).frame(maxWidth: .infinity, minHeight: 145).background(KidsTheme.yellow, in: RoundedRectangle(cornerRadius: 24))
            }.buttonStyle(.plain)
            TextField("输入听到的英文单词", text: $answer)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
                .focused($answerFocused).submitLabel(.done).onSubmit(checkAnswer)
                .padding(15).frame(height: 68).background(.white, in: RoundedRectangle(cornerRadius: 16))
            Button(action: checkAnswer) {
                Label("检查答案", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 56).background(KidsTheme.mint, in: Capsule())
            }.buttonStyle(.plain).disabled(normalizedAnswer.isEmpty).opacity(normalizedAnswer.isEmpty ? 0.5 : 1)
            Spacer(minLength: 0)
        }.padding(22).frame(maxWidth: 620).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultView: some View {
        VStack(spacing: 18) {
            Image(systemName: "ticket.fill").font(.system(size: 66)).foregroundStyle(KidsTheme.orange)
            Text(finalWrongItems.isEmpty ? "听写完成！" : "错词还可以再练")
                .font(.system(size: 27, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink)
            Text("首轮答对 \(firstRoundCorrect) / \(worksheet.items.count) 题。")
                .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(KidsTheme.muted).multilineTextAlignment(.center)
            if !finalWrongItems.isEmpty {
                Text("还有 \(finalWrongItems.count) 个错词。").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(KidsTheme.muted)
            }
            ScrollView { VStack(spacing: 8) {
                ForEach(Array(worksheet.items.enumerated()), id: \.element.id) { offset, item in
                    HStack { Text("\(offset + 1).").foregroundStyle(KidsTheme.muted); Text(item.word).fontWeight(.bold); Spacer(); Button { play(item) } label: { Image(systemName: "speaker.wave.2.fill") } }
                        .font(.system(size: 17, design: .rounded)).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 13))
                }
            } }
            if !finalWrongItems.isEmpty {
                Button("再练错词") { beginRound(with: finalWrongItems, review: true) }
                    .font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink)
                    .frame(maxWidth: 320, minHeight: 52).background(KidsTheme.mint, in: Capsule())
            }
            Button("再练一次") { firstRoundCorrect = 0; result = nil; startRound() }
                .font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink).frame(maxWidth: 320, minHeight: 52).background(KidsTheme.yellow, in: Capsule())
            Button("返回听写单") { dismiss() }.font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(KidsTheme.ink).padding(.horizontal, 22).frame(height: 48).background(.white, in: Capsule())
        }.padding(22).onAppear { saveAttempt() }
    }

    private func checkAnswer() {
        guard let current, !normalizedAnswer.isEmpty else { return }
        answerFocused = false
        let correct = normalizedAnswer == current.word.lowercased()
        var wrongItems = roundWrongItems
        if isReviewRound {
            if !correct && !wrongItems.contains(where: { $0.id == current.id }) { wrongItems.append(current) }
        } else {
            if correct { firstRoundCorrect += 1 }
            else if !wrongItems.contains(where: { $0.id == current.id }) { wrongItems.append(current) }
        }
        if index + 1 < questions.count {
            roundWrongItems = wrongItems
            index += 1
            answer = ""
            playCurrent()
        } else if !isReviewRound && !wrongItems.isEmpty {
            beginRound(with: wrongItems, review: true)
        } else {
            finalWrongItems = wrongItems
            result = firstRoundCorrect
        }
    }

    private func startRound() {
        firstRoundCorrect = 0
        finalWrongItems = []
        didSave = false
        beginRound(with: worksheet.items, review: false)
    }

    private func beginRound(with items: [EnglishWordDictationItem], review: Bool) {
        if result != nil { didSave = false }
        questions = items.shuffled()
        index = 0
        answer = ""
        roundWrongItems = []
        isReviewRound = review
        result = nil
        playCurrent()
    }

    private func playCurrent() { if let current { play(current) } }

    private func play(_ item: EnglishWordDictationItem) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            let store = try EnglishWordDictationStore(userID: app.currentUser.id)
            audioPlayer = try AVAudioPlayer(contentsOf: store.audioURL(worksheetID: worksheet.id, filename: item.audioFilename))
            audioPlayer?.play()
        } catch { errorMessage = "录音无法播放，请联系家长检查这份听写单。" }
    }

    private func recordAttempt(correct: Int) {
        guard let store = try? EnglishWordDictationStore(userID: app.currentUser.id) else { return }
        var updated = store.all().first(where: { $0.id == worksheet.id }) ?? worksheet
        updated.attempts.append(EnglishWordDictationAttempt(id: UUID().uuidString, date: Date(), correct: correct, total: worksheet.items.count))
        try? store.save(updated)
    }

    private func saveAttempt() {
        guard result != nil, !didSave else { return }
        didSave = true
        recordAttempt(correct: firstRoundCorrect)
        onSaved()
    }
}

struct FishEnglishWordDictationTicketPracticeScreen: View {
    let app: AppModel
    let worksheetID: String?
    let onTicketEarned: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var answerFocused: Bool
    @State private var worksheet: EnglishWordDictation?
    @State private var questions: [EnglishWordDictationItem] = []
    @State private var index = 0
    @State private var answer = ""
    @State private var audioPlayer: AVAudioPlayer?
    @State private var roundID = UUID().uuidString
    @State private var restartMessage = false
    @State private var awarded = false
    @State private var errorMessage: String?

    private var current: EnglishWordDictationItem? { questions.indices.contains(index) ? questions[index] : nil }
    private var normalizedAnswer: String { answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if awarded { successView }
                    else if let current { questionView(current) }
                    else if let errorMessage { ContentUnavailableView("找不到英语听写单", systemImage: "waveform.badge.exclamationmark", description: Text(errorMessage)) }
                    else { ProgressView() }
                }.padding(22).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .background { StorybookBackground() }
            .navigationTitle("英语听写 · 赢游戏券").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("退出") { dismiss() } } }
            .keyboardDismissToolbar { answerFocused = false }
        }
        .preferredColorScheme(.light)
        .onAppear { loadWorksheet() }
    }

    private func questionView(_ item: EnglishWordDictationItem) -> some View {
        VStack(spacing: 17) {
            Text("第 \(index + 1) / \(questions.count) 题").font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(KidsTheme.ink)
            ProgressView(value: Double(index), total: Double(max(questions.count, 1))).tint(KidsTheme.orange)
            Text("全部答对赢 1 张游戏券；答错立即重开整轮并换题序。")
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(KidsTheme.muted)
            if restartMessage { Text("答错了，这一轮重新开始了。").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(KidsTheme.red) }
            Button { play(item) } label: {
                VStack(spacing: 10) { Image(systemName: "speaker.wave.2.fill").font(.system(size: 38, weight: .bold)); Text("播放真人录音").font(.system(size: 20, weight: .black, design: .rounded)) }
                    .foregroundStyle(KidsTheme.ink).frame(maxWidth: .infinity, minHeight: 130).background(KidsTheme.yellow, in: RoundedRectangle(cornerRadius: 23))
            }.buttonStyle(.plain)
            TextField("写下听到的英文单词", text: $answer)
                .font(.system(size: 30, weight: .black, design: .rounded)).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.asciiCapable)
                .focused($answerFocused).submitLabel(.done).onSubmit(checkAnswer).padding(15).background(.white, in: RoundedRectangle(cornerRadius: 16))
            Button(action: checkAnswer) {
                Label("检查答案", systemImage: "checkmark.circle.fill").font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(KidsTheme.ink).frame(maxWidth: .infinity, minHeight: 54).background(KidsTheme.mint, in: Capsule())
            }.buttonStyle(.plain).disabled(normalizedAnswer.isEmpty).opacity(normalizedAnswer.isEmpty ? 0.5 : 1)
            Spacer(minLength: 0)
        }
    }

    private var successView: some View {
        VStack(spacing: 18) {
            Image(systemName: "ticket.fill").font(.system(size: 68)).foregroundStyle(KidsTheme.orange)
            Text("全部答对，获得 1 张游戏券！").font(.system(size: 26, weight: .black, design: .rounded)).multilineTextAlignment(.center)
            Text("现在共有 \(app.snakeRewardStatus.ticketCount) 张游戏券").font(.system(size: 17, weight: .bold, design: .rounded))
            Button("返回海底大冒险", action: onTicketEarned).font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(KidsTheme.ink).frame(maxWidth: .infinity, minHeight: 56).background(KidsTheme.yellow, in: Capsule())
            Button("再赢一张") { startRound() }.font(.system(size: 16, weight: .bold, design: .rounded))
        }.foregroundStyle(KidsTheme.ink).padding(.top, 70)
    }

    private func loadWorksheet() {
        guard let worksheetID,
              let stored = try? EnglishWordDictationStore(userID: app.currentUser.id).all().first(where: { $0.id == worksheetID }),
              !stored.items.isEmpty else { errorMessage = "这份听写单可能已被删除，请联系家长重新选择。"; return }
        worksheet = stored
        startRound()
    }

    private func startRound() {
        guard let worksheet, !worksheet.items.isEmpty else { return }
        questions = worksheet.items.shuffled()
        index = 0
        answer = ""
        restartMessage = false
        awarded = false
        roundID = UUID().uuidString
        playCurrent()
    }

    private func checkAnswer() {
        guard let current, !normalizedAnswer.isEmpty else { return }
        answerFocused = false
        guard normalizedAnswer == current.word.lowercased() else {
            recordAttempt(correct: index)
            startRound()
            restartMessage = true
            return
        }
        if index + 1 < questions.count {
            index += 1
            answer = ""
            playCurrent()
        } else {
            recordAttempt(correct: questions.count)
            awarded = app.awardFishPracticeTicket(roundID: roundID)
        }
    }

    private func recordAttempt(correct: Int) {
        guard var worksheet else { return }
        worksheet.attempts.append(EnglishWordDictationAttempt(id: UUID().uuidString, date: Date(), correct: correct, total: worksheet.items.count))
        self.worksheet = worksheet
        try? EnglishWordDictationStore(userID: app.currentUser.id).save(worksheet)
    }

    private func playCurrent() { if let current { play(current) } }

    private func play(_ item: EnglishWordDictationItem) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            let store = try EnglishWordDictationStore(userID: app.currentUser.id)
            audioPlayer = try AVAudioPlayer(contentsOf: store.audioURL(worksheetID: worksheetID ?? "", filename: item.audioFilename))
            audioPlayer?.play()
        } catch { errorMessage = "录音无法播放，请联系家长检查这份听写单。" }
    }
}
