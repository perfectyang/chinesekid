import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import Vision

private enum WorksheetPalette {
    static let ink = KidsTheme.ink
    static let muted = KidsTheme.muted
    static let blue = KidsTheme.blue
    static let yellow = KidsTheme.yellow
    static let mint = KidsTheme.mint
    static let paper = KidsTheme.paper
}

struct PinyinWorksheetItem: Codable, Identifiable {
    var id: String
    var pinyin: String
    var audioFilename: String
}

struct PinyinWorksheetAttempt: Codable, Identifiable {
    var id: String
    var date: Date
    var correct: Int
    var total: Int
}

struct PinyinWorksheet: Codable, Identifiable {
    var id: String
    var userID: String
    var name: String
    var createdAt: Date
    var items: [PinyinWorksheetItem]
    var attempts: [PinyinWorksheetAttempt]
}

@MainActor
final class PinyinWorksheetStore {
    private let root: URL
    private let userID: String

    init(userID: String) throws {
        self.userID = userID
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        root = support.appendingPathComponent("PinyinDictations", isDirectory: true).appendingPathComponent(Self.safe(userID), isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func all() -> [PinyinWorksheet] {
        guard let folders = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        return folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("worksheet.json")),
                  let worksheet = try? JSONDecoder().decode(PinyinWorksheet.self, from: data) else { return nil }
            return worksheet
        }.sorted { $0.createdAt > $1.createdAt }
    }

    func audioURL(worksheetID: String, filename: String) -> URL {
        root.appendingPathComponent(Self.safe(worksheetID), isDirectory: true).appendingPathComponent(filename)
    }

    func saveDraft(id: String, name: String, pinyin: [String], audioURLs: [URL]) throws -> PinyinWorksheet {
        let folder = root.appendingPathComponent(Self.safe(id), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var items: [PinyinWorksheetItem] = []
        for (index, value) in pinyin.enumerated() {
            let filename = "item-\(index).m4a"
            let destination = folder.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.copyItem(at: audioURLs[index], to: destination)
            items.append(PinyinWorksheetItem(id: UUID().uuidString, pinyin: value, audioFilename: filename))
        }
        let worksheet = PinyinWorksheet(id: id, userID: userID, name: name, createdAt: Date(), items: items, attempts: [])
        try write(worksheet, in: folder)
        return worksheet
    }

    func update(_ existing: PinyinWorksheet, name: String, pinyin: [String], audioURLs: [URL]) throws {
        let folder = root.appendingPathComponent(Self.safe(existing.id), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let changed = existing.items.map(\.pinyin) != pinyin || existing.items.count != audioURLs.count || existing.items.enumerated().contains { index, item in
            guard audioURLs.indices.contains(index) else { return true }
            let originalURL = folder.appendingPathComponent(item.audioFilename)
            return audioURLs[index].standardizedFileURL != originalURL.standardizedFileURL
        }
        var items: [PinyinWorksheetItem] = []
        for (index, value) in pinyin.enumerated() {
            let filename = "item-\(index).m4a"
            let destination = folder.appendingPathComponent(filename)
            let source = audioURLs[index]
            if source.standardizedFileURL != destination.standardizedFileURL {
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.copyItem(at: source, to: destination)
            }
            let preservedID = existing.items.indices.contains(index) && existing.items[index].pinyin == value
                ? existing.items[index].id
                : UUID().uuidString
            items.append(PinyinWorksheetItem(id: preservedID, pinyin: value, audioFilename: filename))
        }
        let keepFiles = Set(items.map(\.audioFilename))
        for item in existing.items where !keepFiles.contains(item.audioFilename) {
            let oldFile = folder.appendingPathComponent(item.audioFilename)
            try? FileManager.default.removeItem(at: oldFile)
        }
        let updated = PinyinWorksheet(
            id: existing.id,
            userID: userID,
            name: name,
            createdAt: existing.createdAt,
            items: items,
            attempts: changed ? [] : existing.attempts
        )
        try write(updated, in: folder)
    }

    func save(_ worksheet: PinyinWorksheet) throws {
        let folder = root.appendingPathComponent(Self.safe(worksheet.id), isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try write(worksheet, in: folder)
    }

    func delete(_ worksheet: PinyinWorksheet) throws {
        let folder = root.appendingPathComponent(Self.safe(worksheet.id), isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    }

    private func write(_ worksheet: PinyinWorksheet, in folder: URL) throws {
        let data = try JSONEncoder().encode(worksheet)
        try data.write(to: folder.appendingPathComponent("worksheet.json"), options: .atomic)
    }

    private static func safe(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "..", with: "_")
    }
}

struct PinyinWorksheetDictationScreen: View {
    let app: AppModel
    @State private var worksheets: [PinyinWorksheet] = []
    @State private var showingImport = false
    @State private var showingEdit = false
    @State private var editingWorksheetID: String?
    @State private var alertMessage: String?
    @State private var deletingWorksheet: PinyinWorksheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("我的听写单")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(WorksheetPalette.ink)
                    Text("上传练习纸，录下每个拼音，下次可以继续听写。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(WorksheetPalette.muted)
                }

                Button { showingImport = true } label: {
                    Label("上传一份练习", systemImage: "camera.viewfinder")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(WorksheetPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(WorksheetPalette.yellow, in: Capsule())
                }
                .buttonStyle(.plain)

                if worksheets.isEmpty {
                    ContentUnavailableView("还没有听写单", systemImage: "pencil.and.list.clipboard", description: Text("上传练习纸后，就会出现在这里。"))
                        .padding(.top, 25)
                } else {
                    ForEach(worksheets) { worksheet in
                        NavigationLink {
                            PinyinWorksheetGameScreen(worksheet: worksheet, app: app) { reload() }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(worksheet.name)
                                        .font(.system(size: 19, weight: .black, design: .rounded))
                                        .foregroundStyle(WorksheetPalette.ink)
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 27))
                                        .foregroundStyle(WorksheetPalette.ink)
                                }
                                HStack {
                                    Text("\(worksheet.items.count) 个拼音")
                                    Text("·")
                                    Text(worksheet.attempts.isEmpty ? "还没练习" : "已练 \(worksheet.attempts.count) 次")
                                    if let latest = worksheet.attempts.last {
                                        Text("· 最近 \(latest.correct)/\(latest.total)")
                                    }
                                    Spacer()
                                    Button {
                                        editingWorksheetID = worksheet.id
                                        showingEdit = true
                                    } label: {
                                        Image(systemName: "pencil")
                                            .padding(9)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("编辑听写单")
                                    Button(role: .destructive) { deletingWorksheet = worksheet } label: {
                                        Image(systemName: "trash")
                                            .padding(9)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(WorksheetPalette.muted)
                            }
                            .padding(16)
                            .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background { StorybookBackground() }
        .navigationTitle("拼音听写")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingImport) {
            PinyinWorksheetImportScreen(app: app) { reload() }
        }
        .navigationDestination(isPresented: $showingEdit) {
            if let editingWorksheetID,
               let worksheet = worksheets.first(where: { $0.id == editingWorksheetID }) {
                PinyinWorksheetImportScreen(app: app, existingWorksheet: worksheet) { reload() }
            } else {
                ContentUnavailableView("找不到听写单", systemImage: "questionmark.folder")
            }
        }
        .confirmationDialog("删除这份听写单？", isPresented: Binding(
            get: { deletingWorksheet != nil }, set: { if !$0 { deletingWorksheet = nil } }
        ), titleVisibility: .visible) {
            Button("删除听写单", role: .destructive) {
                guard let deletingWorksheet else { return }
                do { try store().delete(deletingWorksheet); reload() }
                catch { alertMessage = "删除失败，请稍后再试。" }
                self.deletingWorksheet = nil
            }
            Button("取消", role: .cancel) { deletingWorksheet = nil }
        }
        .alert("听写单", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("知道了", role: .cancel) { alertMessage = nil }
        } message: { Text(alertMessage ?? "") }
        .onAppear(perform: reload)
    }

    private func store() throws -> PinyinWorksheetStore { try PinyinWorksheetStore(userID: app.currentUser.id) }
    private func reload() { worksheets = (try? store().all()) ?? [] }
}

private struct PinyinWorksheetImportScreen: View {
    let app: AppModel
    let onSaved: () -> Void
    let existingWorksheet: PinyinWorksheet?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedPinyinIndex: Int?
    @State private var photo: PhotosPickerItem?
    @State private var cameraImage: UIImage?
    @State private var showingCamera = false
    @State private var name: String
    @State private var pinyin: [String]
    @State private var audioFiles: [URL?] = []
    @State private var activeRecorder: AVAudioRecorder?
    @State private var activeRecordingIndex: Int?
    @State private var recordingStartedAt: Date?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isRecognizing = false
    @State private var notice: String?
    @State private var draftID: String
    @State private var recordingPermission = true
    @State private var didLoadExistingAudio = false

    init(app: AppModel, existingWorksheet: PinyinWorksheet? = nil, onSaved: @escaping () -> Void) {
        self.app = app
        self.existingWorksheet = existingWorksheet
        self.onSaved = onSaved
        _name = State(initialValue: existingWorksheet?.name ?? "拼音听写")
        _pinyin = State(initialValue: existingWorksheet?.items.map(\.pinyin) ?? [])
        _audioFiles = State(initialValue: Array(repeating: nil, count: existingWorksheet?.items.count ?? 0))
        _draftID = State(initialValue: existingWorksheet?.id ?? UUID().uuidString)
        _didLoadExistingAudio = State(initialValue: existingWorksheet == nil)
    }

    private var allRecorded: Bool {
        !pinyin.isEmpty && audioFiles.count == pinyin.count && audioFiles.allSatisfy { $0 != nil }
            && (existingWorksheet == nil || didLoadExistingAudio)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text(existingWorksheet == nil
                     ? "先给练习起个名字，再确认拼音并录下读音。照片识别后不会保存。"
                     : "可以修改名称、拼音和录音，也可以增删拼音。内容有变化时，旧成绩会清除。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(WorksheetPalette.muted)

                if pinyin.isEmpty {
                    TextField("听写单名称", text: $name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .padding(15)
                        .background(.white, in: RoundedRectangle(cornerRadius: 15))
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("从相册选择练习照片", systemImage: "photo")
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(WorksheetPalette.mint, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) { showingCamera = true }
                        else { notice = "当前设备没有可用的相机，可以从相册选择照片。" }
                    } label: {
                        Label("现在拍照", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(WorksheetPalette.yellow, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        pinyin = [""]
                        audioFiles = [nil]
                        draftID = UUID().uuidString
                        notice = nil
                    } label: {
                        Label("手动输入拼音", systemImage: "text.cursor")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(WorksheetPalette.blue.opacity(0.55), in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    TextField("听写单名称", text: $name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .padding(15)
                        .background(.white, in: RoundedRectangle(cornerRadius: 15))

                    Text("检查识别结果，点拼音可修改；每题录音后可试听或重录。")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(WorksheetPalette.muted)

                    ForEach(pinyin.indices, id: \.self) { index in
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(WorksheetPalette.muted)
                                TextField("拼音", text: $pinyin[index])
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .frame(width: 88)
                                    .focused($focusedPinyinIndex, equals: index)
                                    .submitLabel(.done)
                                    .onSubmit { focusedPinyinIndex = nil }
                                Spacer()
                                if audioFiles[index] != nil {
                                    Button { play(index) } label: { Image(systemName: "play.circle.fill") }
                                        .font(.system(size: 27))
                                }
                                Button { Task { await toggleRecording(index) } } label: {
                                    Label(activeRecordingIndex == index ? "停止" : (audioFiles[index] == nil ? "录音" : "重录"), systemImage: activeRecordingIndex == index ? "stop.circle.fill" : "mic.circle.fill")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .tint(activeRecordingIndex == index ? .red : WorksheetPalette.ink)
                                Button(role: .destructive) {
                                    guard activeRecordingIndex != index else { return }
                                    pinyin.remove(at: index)
                                    audioFiles.remove(at: index)
                                } label: { Image(systemName: "minus.circle") }
                                    .font(.system(size: 21))
                                    .disabled(activeRecordingIndex != nil)
                            }
                            HStack(spacing: 7) {
                                Text("加声调")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(WorksheetPalette.muted)
                                ForEach(1...4, id: \.self) { tone in
                                    toneButton("\(tone)声", tone: tone, index: index)
                                }
                                toneButton("轻声", tone: 0, index: index)
                                Spacer(minLength: 0)
                            }
                        }
                        .foregroundStyle(WorksheetPalette.ink)
                        .padding(13)
                        .background(.white, in: RoundedRectangle(cornerRadius: 17))
                        .onChange(of: pinyin[index]) { oldValue, newValue in
                            if oldValue != newValue { audioFiles[index] = nil }
                        }
                    }

                    Button {
                        pinyin.append("")
                        audioFiles.append(nil)
                    } label: {
                        Label("添加一个拼音", systemImage: "plus.circle.fill")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }

                    Button(action: save) {
                        Label(existingWorksheet == nil ? "保存听写单" : "保存修改", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(WorksheetPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(WorksheetPalette.mint, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!allRecorded || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || activeRecordingIndex != nil)
                    .opacity(allRecorded && activeRecordingIndex == nil ? 1 : 0.5)
                }

                if isRecognizing { ProgressView("正在识别拼音…").frame(maxWidth: .infinity).padding() }
                if let notice {
                    Text(notice).font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(WorksheetPalette.ink).padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WorksheetPalette.yellow.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(20)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { StorybookBackground() }
        .navigationTitle(existingWorksheet == nil ? "新建听写单" : "编辑听写单")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDismissToolbar { focusedPinyinIndex = nil }
        .onAppear(perform: loadExistingAudio)
        .onChange(of: photo) { _, selected in
            guard let selected else { return }
            Task {
                do { if let data = try await selected.loadTransferable(type: Data.self) { await recognize(data) } }
                catch { notice = "照片读取失败，请重新选择。" }
            }
        }
        .sheet(isPresented: $showingCamera) {
            PinyinWorksheetCameraPicker(image: $cameraImage).ignoresSafeArea()
        }
        .onChange(of: cameraImage) { _, image in
            guard let image, let data = image.jpegData(compressionQuality: 0.95) else { return }
            Task { await recognize(data) }
        }
        .onDisappear { if activeRecordingIndex != nil { finishRecording() } }
    }

    @MainActor
    private func recognize(_ data: Data) async {
        isRecognizing = true
        notice = nil
        defer { isRecognizing = false }
        do {
            let found = try PinyinWorksheetOCR.recognize(data)
            guard !found.isEmpty else { notice = "没有识别到拼音。请拍清楚一些，或重新拍摄。"; return }
            pinyin = found
            audioFiles = Array(repeating: nil, count: found.count)
            draftID = UUID().uuidString
        } catch { notice = "识别失败，请重新拍摄或从相册选择。" }
    }

    private func toggleRecording(_ index: Int) async {
        if activeRecordingIndex == index { finishRecording(); return }
        if activeRecordingIndex != nil { finishRecording() }
        if !recordingPermission {
            notice = "请在系统设置中允许使用麦克风后再录音。"
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard granted else { recordingPermission = false; notice = "请允许使用麦克风来录制拼音。"; return }
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PinyinWorksheet-\(draftID)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("item-\(index).m4a")
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            guard recorder.prepareToRecord(), recorder.record() else {
                notice = "录音没有启动，请检查麦克风权限或重试。"
                return
            }
            activeRecorder = recorder
            activeRecordingIndex = index
            recordingStartedAt = Date()
            notice = "请清楚地读出：\(pinyin[index])"
        } catch { notice = "无法开始录音，请检查麦克风权限。" }
    }

    private func finishRecording() {
        guard let recorder = activeRecorder, let index = activeRecordingIndex else { return }
        let elapsed = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        recorder.stop()
        let url = recorder.url
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if elapsed <= 0.25 {
            notice = "录音太短了，请再录一次。"
        } else if fileSize <= 512 {
            notice = "没有收到有效录音，请检查麦克风权限或输入设备。"
        } else {
            audioFiles[index] = url
            notice = "录音已保存，可以试听或重录。"
        }
        activeRecorder = nil
        activeRecordingIndex = nil
        recordingStartedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func play(_ index: Int) {
        guard let url = audioFiles[index] else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch { notice = "录音播放失败，可以重新录制。" }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = pinyin.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let urls = audioFiles.compactMap { $0 }
        guard !cleanName.isEmpty, cleaned.allSatisfy({ !$0.isEmpty }), allRecorded, urls.count == cleaned.count else { return }
        do {
            let store = try PinyinWorksheetStore(userID: app.currentUser.id)
            if let existingWorksheet {
                try store.update(existingWorksheet, name: String(cleanName.prefix(40)), pinyin: cleaned, audioURLs: urls)
            } else {
                _ = try store.saveDraft(id: draftID, name: String(cleanName.prefix(40)), pinyin: cleaned, audioURLs: urls)
            }
            let draftFolder = FileManager.default.temporaryDirectory.appendingPathComponent("PinyinWorksheet-\(draftID)", isDirectory: true)
            try? FileManager.default.removeItem(at: draftFolder)
            onSaved()
            dismiss()
        } catch { notice = "保存失败，请检查设备存储空间后重试。" }
    }

    private func loadExistingAudio() {
        guard let existingWorksheet, !didLoadExistingAudio else { return }
        do {
            let store = try PinyinWorksheetStore(userID: app.currentUser.id)
            audioFiles = existingWorksheet.items.map { item in
                let url = store.audioURL(worksheetID: existingWorksheet.id, filename: item.audioFilename)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
            didLoadExistingAudio = true
        } catch {
            notice = "无法读取这份听写单的录音，请稍后重试。"
        }
    }

    private func toneButton(_ title: String, tone: Int, index: Int) -> some View {
        Button(title) {
            pinyin[index] = applyToneMark(tone, to: pinyin[index])
            focusedPinyinIndex = nil
        }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(WorksheetPalette.ink)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(WorksheetPalette.blue.opacity(0.45), in: Capsule())
            .buttonStyle(.plain)
            .accessibilityLabel(tone == 0 ? "标为轻声" : "标为第\(tone)声")
    }
}

private func applyToneMark(_ tone: Int, to input: String) -> String {
    let marks: [Character: [Character]] = [
        "a": ["ā", "á", "ǎ", "à"], "e": ["ē", "é", "ě", "è"], "i": ["ī", "í", "ǐ", "ì"],
        "o": ["ō", "ó", "ǒ", "ò"], "u": ["ū", "ú", "ǔ", "ù"], "ü": ["ǖ", "ǘ", "ǚ", "ǜ"], "v": ["ǖ", "ǘ", "ǚ", "ǜ"]
    ]
    let plainForMark: [Character: Character] = [
        "ā": "a", "á": "a", "ǎ": "a", "à": "a", "ē": "e", "é": "e", "ě": "e", "è": "e",
        "ī": "i", "í": "i", "ǐ": "i", "ì": "i", "ō": "o", "ó": "o", "ǒ": "o", "ò": "o",
        "ū": "u", "ú": "u", "ǔ": "u", "ù": "u", "ǖ": "ü", "ǘ": "ü", "ǚ": "ü", "ǜ": "ü"
    ]
    var chars = Array(input.lowercased())
    for index in chars.indices {
        if let base = plainForMark[chars[index]] { chars[index] = base }
    }
    guard (1...4).contains(tone) else { return String(chars) }
    let vowelIndex: Int?
    if let a = chars.firstIndex(of: "a") { vowelIndex = a }
    else if let e = chars.firstIndex(of: "e") { vowelIndex = e }
    else if let ou = chars.indices.first(where: { $0 + 1 < chars.count && chars[$0] == "o" && chars[$0 + 1] == "u" }) { vowelIndex = ou }
    else { vowelIndex = chars.indices.reversed().first(where: { "iouüv".contains(chars[$0]) }) }
    if let vowelIndex, let options = marks[chars[vowelIndex]] { chars[vowelIndex] = options[tone - 1] }
    return String(chars)
}

private struct PinyinVowelOption: Identifiable {
    let index: Int
    let label: String
    var id: Int { index }
}

private enum PinyinToneResponse {
    private static let toneMarks: [Character: (base: Character, tone: Int)] = [
        "ā": ("a", 1), "á": ("a", 2), "ǎ": ("a", 3), "à": ("a", 4),
        "ē": ("e", 1), "é": ("e", 2), "ě": ("e", 3), "è": ("e", 4),
        "ī": ("i", 1), "í": ("i", 2), "ǐ": ("i", 3), "ì": ("i", 4),
        "ō": ("o", 1), "ó": ("o", 2), "ǒ": ("o", 3), "ò": ("o", 4),
        "ū": ("u", 1), "ú": ("u", 2), "ǔ": ("u", 3), "ù": ("u", 4),
        "ǖ": ("ü", 1), "ǘ": ("ü", 2), "ǚ": ("ü", 3), "ǜ": ("ü", 4)
    ]

    private static let marks: [Character: [Character]] = [
        "a": ["ā", "á", "ǎ", "à"], "e": ["ē", "é", "ě", "è"], "i": ["ī", "í", "ǐ", "ì"],
        "o": ["ō", "ó", "ǒ", "ò"], "u": ["ū", "ú", "ǔ", "ù"], "ü": ["ǖ", "ǘ", "ǚ", "ǜ"], "v": ["ǖ", "ǘ", "ǚ", "ǜ"]
    ]

    static func letters(_ value: String) -> String {
        let characters = value.lowercased().compactMap { character -> Character? in
            if let mark = toneMarks[character] { return mark.base }
            guard character.isLetter else { return nil }
            return character
        }
        return String(characters)
    }

    static func vowelOptions(in value: String) -> [PinyinVowelOption] {
        Array(letters(value)).enumerated().compactMap { index, character in
            guard "aeiouüv".contains(character) else { return nil }
            return PinyinVowelOption(index: index, label: character == "v" ? "ü" : String(character))
        }
    }

    static func markedAnswer(_ value: String, vowelIndex: Int?, tone: Int?) -> String {
        var characters = Array(letters(value))
        guard let tone, (1...4).contains(tone), let vowelIndex,
              characters.indices.contains(vowelIndex), let alternatives = marks[characters[vowelIndex]] else {
            return String(characters)
        }
        characters[vowelIndex] = alternatives[tone - 1]
        return String(characters)
    }

    static func scoreKey(_ value: String, vowelIndex: Int?, tone: Int?) -> String? {
        guard let tone else { return nil }
        let spelling = normalizedLetters(letters(value))
        guard tone == 0 else {
            guard let vowelIndex else { return nil }
            return "\(spelling)|\(tone)|\(vowelIndex)"
        }
        return "\(spelling)|0|-1"
    }

    static func expectedKey(_ value: String) -> String {
        var base = ""
        var markedIndex: Int?
        var tone = 0
        for character in value.lowercased() {
            if let mark = toneMarks[character] {
                markedIndex = base.count
                tone = mark.tone
                base.append(mark.base)
            } else if character.isNumber, let digit = character.wholeNumberValue, (1...5).contains(digit) {
                tone = digit == 5 ? 0 : digit
            } else if character.isLetter {
                base.append(character)
            }
        }
        if tone > 0, markedIndex == nil { markedIndex = standardTonePosition(in: base) }
        return "\(normalizedLetters(base))|\(tone)|\(tone == 0 ? -1 : (markedIndex ?? -1))"
    }

    private static func normalizedLetters(_ value: String) -> String {
        value.replacingOccurrences(of: "ü", with: "v")
    }

    private static func standardTonePosition(in value: String) -> Int? {
        let characters = Array(value)
        if let index = characters.firstIndex(of: "a") { return index }
        if let index = characters.firstIndex(of: "e") { return index }
        if let index = characters.indices.first(where: { $0 + 1 < characters.count && characters[$0] == "o" && characters[$0 + 1] == "u" }) { return index }
        return characters.indices.reversed().first(where: { "iouüv".contains(characters[$0]) })
    }
}

private struct PinyinToneAnswerControls: View {
    let spelling: String
    @Binding var selectedVowelIndex: Int?
    @Binding var selectedTone: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("选声调标记的位置")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(WorksheetPalette.muted)
            let vowels = PinyinToneResponse.vowelOptions(in: spelling)
            HStack(spacing: 8) {
                ForEach(vowels) { vowel in
                    Button {
                        selectedVowelIndex = vowel.index
                        if selectedTone == 0 { selectedTone = nil }
                    } label: {
                        Text(vowel.label)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(WorksheetPalette.ink)
                            .frame(minWidth: 42, minHeight: 42)
                            .background(selectedVowelIndex == vowel.index ? WorksheetPalette.yellow : .white, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("再选听到的声调")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(WorksheetPalette.muted)
            HStack(spacing: 7) {
                ForEach(1...4, id: \.self) { tone in
                    toneButton("\(tone)声", value: tone)
                }
                toneButton("轻声", value: 0)
            }
        }
        .padding(12)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
    }

    private func toneButton(_ title: String, value: Int) -> some View {
        Button(title) {
            selectedTone = value
            if value == 0 { selectedVowelIndex = nil }
        }
        .font(.system(size: 13, weight: .black, design: .rounded))
        .foregroundStyle(WorksheetPalette.ink)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(selectedTone == value ? WorksheetPalette.blue : .white, in: Capsule())
        .buttonStyle(.plain)
    }
}

private struct PinyinWorksheetGameScreen: View {
    let worksheet: PinyinWorksheet
    let app: AppModel
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var answerFocused: Bool
    @State private var index = 0
    @State private var questions: [PinyinWorksheetItem] = []
    @State private var answer = ""
    @State private var selectedVowelIndex: Int?
    @State private var selectedTone: Int?
    @State private var answers: [String] = []
    @State private var roundWrongItems: [PinyinWorksheetItem] = []
    @State private var finalWrongItems: [PinyinWorksheetItem] = []
    @State private var firstRoundCorrectCount = 0
    @State private var firstRoundQuestionCount = 0
    @State private var isReviewRound = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var result: Int?
    @State private var alertMessage: String?
    @State private var didPersistResult = false

    private var current: PinyinWorksheetItem? { questions.indices.contains(index) ? questions[index] : nil }
    private var answerIsReady: Bool {
        !PinyinToneResponse.letters(answer).isEmpty
            && PinyinToneResponse.scoreKey(answer, vowelIndex: selectedVowelIndex, tone: selectedTone) != nil
    }

    var body: some View {
        Group {
            if result != nil { resultView }
            else if let current { questionView(current) }
            else { ContentUnavailableView("這份聽寫單沒有題目", systemImage: "questionmark.folder") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { StorybookBackground() }
        .navigationTitle(worksheet.name)
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDismissToolbar { answerFocused = false }
        .onAppear {
            guard questions.isEmpty else { return }
            firstRoundQuestionCount = worksheet.items.count
            answers = Array(repeating: "", count: worksheet.items.count)
            beginRound(with: worksheet.items, review: false)
        }
        .alert("听写", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("知道了", role: .cancel) { alertMessage = nil }
        } message: { Text(alertMessage ?? "") }
    }

    private func questionView(_ item: PinyinWorksheetItem) -> some View {
        VStack(spacing: 21) {
            HStack {
                Text(isReviewRound ? "错题复习 · 第 \(index + 1) / \(questions.count) 题" : "第 \(index + 1) / \(questions.count) 题")
                Spacer()
                Text(worksheet.name)
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(WorksheetPalette.muted)
            ProgressView(value: Double(index + 1), total: Double(max(questions.count, 1))).tint(KidsTheme.orange)

            Button(action: playCurrent) {
                VStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 43, weight: .bold))
                    Text("播放我的录音").font(.system(size: 21, weight: .black, design: .rounded))
                }
                .foregroundStyle(WorksheetPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 155)
                .background(WorksheetPalette.yellow, in: RoundedRectangle(cornerRadius: 26))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 11) {
                Text("先写拼音字母，再自己选择声调位置和声调")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(WorksheetPalette.muted)
                TextField("在这里输入拼音", text: $answer)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .focused($answerFocused)
                    .submitLabel(.done)
                    .onSubmit(advance)
                    .onChange(of: answer) { _, newValue in
                        let clean = PinyinToneResponse.letters(newValue)
                        if clean != newValue { answer = clean; return }
                        selectedVowelIndex = nil
                        selectedTone = nil
                    }
                    .padding(15)
                    .frame(height: 70)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                PinyinToneAnswerControls(spelling: answer, selectedVowelIndex: $selectedVowelIndex, selectedTone: $selectedTone)
                if answerIsReady {
                    Text("你的答案：\(PinyinToneResponse.markedAnswer(answer, vowelIndex: selectedVowelIndex, tone: selectedTone))")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(WorksheetPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button(action: advance) {
                Label(index + 1 == questions.count ? "完成本轮" : "下一题", systemImage: "arrow.right.circle.fill")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(WorksheetPalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(WorksheetPalette.mint, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!answerIsReady)
            .opacity(answerIsReady ? 1 : 0.5)
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultView: some View {
        VStack(spacing: 16) {
            Image(systemName: finalWrongItems.isEmpty ? "star.circle.fill" : "repeat.circle.fill")
                .font(.system(size: 68)).foregroundStyle(WorksheetPalette.yellow)
            Text(finalWrongItems.isEmpty
                 ? (firstRoundCorrectCount == firstRoundQuestionCount ? "听写完成" : "错题都听会啦！")
                 : "错题还可以再练")
                .font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(WorksheetPalette.ink)
            Text("首轮答对 \(firstRoundCorrectCount) / \(firstRoundQuestionCount) 题")
                .font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(WorksheetPalette.ink)
            if !finalWrongItems.isEmpty {
                Text("还有 \(finalWrongItems.count) 道错题。")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WorksheetPalette.muted)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(worksheet.items.enumerated()), id: \.element.id) { offset, item in
                        HStack {
                            Text("\(offset + 1). \(item.pinyin)").fontWeight(.bold)
                            Spacer()
                            Text(answers.indices.contains(offset) ? answers[offset] : "")
                                .foregroundStyle(
                                    answers.indices.contains(offset) && PinyinToneResponse.expectedKey(answers[offset]) == PinyinToneResponse.expectedKey(item.pinyin)
                                        ? .green : .red
                                )
                        }
                        .font(.system(size: 17, design: .rounded))
                        .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
            }
            if !finalWrongItems.isEmpty {
                Button("再练错题") {
                    beginRound(with: finalWrongItems, review: true)
                }
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(WorksheetPalette.ink).frame(maxWidth: 320, minHeight: 52)
                .background(WorksheetPalette.blue.opacity(0.6), in: Capsule())
            }
            Button("再练一次") { restart() }
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(WorksheetPalette.ink).frame(maxWidth: 320, minHeight: 52)
                .background(WorksheetPalette.yellow, in: Capsule())
            Button("返回听写单") { dismiss() }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WorksheetPalette.ink).padding(.horizontal, 22).frame(height: 48)
                .background(.white, in: Capsule())
        }
        .padding(22)
        .onAppear(perform: saveAttempt)
    }

    private func advance() {
        guard answerIsReady, let current else { return }
        answerFocused = false
        let submitted = PinyinToneResponse.markedAnswer(answer, vowelIndex: selectedVowelIndex, tone: selectedTone)
        let isCorrect = PinyinToneResponse.expectedKey(submitted) == PinyinToneResponse.expectedKey(current.pinyin)
        if !isReviewRound, let originalIndex = worksheet.items.firstIndex(where: { $0.id == current.id }) {
            answers[originalIndex] = submitted
            if isCorrect { firstRoundCorrectCount += 1 }
        }
        var wrongItems = roundWrongItems
        if !isCorrect && !wrongItems.contains(where: { $0.id == current.id }) { wrongItems.append(current) }

        if index + 1 < questions.count {
            roundWrongItems = wrongItems
            index += 1
            answer = ""
            selectedVowelIndex = nil
            selectedTone = nil
            playCurrent()
        } else {
            finishRound(with: wrongItems)
        }
    }

    private func restart() {
        firstRoundCorrectCount = 0
        firstRoundQuestionCount = worksheet.items.count
        answers = Array(repeating: "", count: worksheet.items.count)
        finalWrongItems = []
        didPersistResult = false
        beginRound(with: worksheet.items, review: false)
    }

    private func beginRound(with items: [PinyinWorksheetItem], review: Bool) {
        questions = items
        index = 0
        answer = ""
        roundWrongItems = []
        isReviewRound = review
        result = nil
        selectedVowelIndex = nil
        selectedTone = nil
        playCurrent()
    }

    private func finishRound(with wrongItems: [PinyinWorksheetItem]) {
        roundWrongItems = []
        if wrongItems.isEmpty {
            finalWrongItems = []
            result = firstRoundCorrectCount
        } else if !isReviewRound {
            finalWrongItems = wrongItems
            beginRound(with: wrongItems, review: true)
        } else {
            finalWrongItems = wrongItems
            result = firstRoundCorrectCount
        }
    }

    private func playCurrent() {
        guard let current else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            audioPlayer = try AVAudioPlayer(contentsOf: PinyinWorksheetStore(userID: app.currentUser.id).audioURL(worksheetID: worksheet.id, filename: current.audioFilename))
            audioPlayer?.play()
        } catch { alertMessage = "录音无法播放，请返回后重新录制这道题。" }
    }

    private func saveAttempt() {
        guard result != nil, !didPersistResult else { return }
        didPersistResult = true
        var updated = worksheet
        updated.attempts.append(PinyinWorksheetAttempt(id: UUID().uuidString, date: Date(), correct: firstRoundCorrectCount, total: firstRoundQuestionCount))
        do {
            try PinyinWorksheetStore(userID: app.currentUser.id).save(updated)
            onSaved()
        } catch { alertMessage = "成绩暂时没有保存成功。" }
    }

}

struct FishHumanDictationTicketPracticeScreen: View {
    let app: AppModel
    let worksheetID: String?
    let onTicketEarned: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var answerFocused: Bool
    @State private var worksheet: PinyinWorksheet?
    @State private var questions: [PinyinWorksheetItem] = []
    @State private var questionIndex = 0
    @State private var answer = ""
    @State private var selectedVowelIndex: Int?
    @State private var selectedTone: Int?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var roundID = UUID().uuidString
    @State private var restartMessage = false
    @State private var awarded = false
    @State private var loadError: String?

    private var current: PinyinWorksheetItem? { questions.indices.contains(questionIndex) ? questions[questionIndex] : nil }
    private var answerIsReady: Bool {
        !PinyinToneResponse.letters(answer).isEmpty
            && PinyinToneResponse.scoreKey(answer, vowelIndex: selectedVowelIndex, tone: selectedTone) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if awarded { successView }
                    else if let current { questionView(current) }
                    else if let loadError {
                        ContentUnavailableView("找不到听写单", systemImage: "waveform.badge.exclamationmark", description: Text(loadError))
                    } else { ProgressView() }
                }
                .padding(22)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background { StorybookBackground() }
            .navigationTitle("真人听写 · 赢游戏券")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("退出") { dismiss() }
                }
            }
            .keyboardDismissToolbar { answerFocused = false }
        }
        .preferredColorScheme(.light)
        .onAppear { loadWorksheet() }
    }

    private func questionView(_ item: PinyinWorksheetItem) -> some View {
        VStack(spacing: 18) {
            Text("第 \(questionIndex + 1) / \(questions.count) 题")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
            ProgressView(value: Double(questionIndex), total: Double(max(questions.count, 1)))
                .tint(KidsTheme.orange)
            Text("听写你录制的读音，全部答对赢 1 张游戏券")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(KidsTheme.muted)
            if restartMessage {
                Text("再听一次，整份听写单重新开始了。")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(KidsTheme.red)
            }

            Button { play(item) } label: {
                VStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 38, weight: .bold))
                    Text("播放真人录音").font(.system(size: 20, weight: .black, design: .rounded))
                }
                .foregroundStyle(KidsTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 130)
                .background(KidsTheme.yellow, in: RoundedRectangle(cornerRadius: 23))
            }
            .buttonStyle(.plain)

            VStack(spacing: 10) {
                TextField("写下听到的拼音", text: $answer)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .focused($answerFocused)
                    .onSubmit(checkAnswer)
                    .onChange(of: answer) { _, newValue in
                        let clean = PinyinToneResponse.letters(newValue)
                        if clean != newValue { answer = clean; return }
                        selectedVowelIndex = nil
                        selectedTone = nil
                    }
                    .padding(15)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                PinyinToneAnswerControls(spelling: answer, selectedVowelIndex: $selectedVowelIndex, selectedTone: $selectedTone)
                if answerIsReady {
                    Text("你的答案：\(PinyinToneResponse.markedAnswer(answer, vowelIndex: selectedVowelIndex, tone: selectedTone))")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(KidsTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(action: checkAnswer) {
                    Label("检查答案", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(KidsTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(KidsTheme.mint, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!answerIsReady)
            }
            Spacer(minLength: 0)
        }
    }

    private var successView: some View {
        VStack(spacing: 18) {
            Image(systemName: "ticket.fill").font(.system(size: 68)).foregroundStyle(KidsTheme.orange)
            Text("全部答对，获得 1 张游戏券！")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Text("现在共有 \(app.snakeRewardStatus.ticketCount) 张游戏券")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Button("返回海底大冒险", action: onTicketEarned)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(KidsTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(KidsTheme.yellow, in: Capsule())
            Button("再赢一张") { startRound() }
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .foregroundStyle(KidsTheme.ink)
        .padding(.top, 70)
    }

    @MainActor
    private func loadWorksheet() {
        guard let worksheetID,
              let stored = try? PinyinWorksheetStore(userID: app.currentUser.id).all().first(where: { $0.id == worksheetID }),
              !stored.items.isEmpty else {
            loadError = "这份听写单可能已被删除，请联系家长重新选择。"
            return
        }
        worksheet = stored
        startRound()
    }

    @MainActor
    private func startRound() {
        guard let worksheet, !worksheet.items.isEmpty else { return }
        questions = worksheet.items.shuffled()
        questionIndex = 0
        answer = ""
        selectedVowelIndex = nil
        selectedTone = nil
        restartMessage = false
        awarded = false
        roundID = UUID().uuidString
        playCurrent()
    }

    @MainActor
    private func checkAnswer() {
        guard let current else { return }
        guard answerIsReady,
              let submitted = PinyinToneResponse.scoreKey(answer, vowelIndex: selectedVowelIndex, tone: selectedTone) else { return }
        answerFocused = false
        guard submitted == PinyinToneResponse.expectedKey(current.pinyin) else {
            recordAttempt(correct: questionIndex)
            startRound()
            restartMessage = true
            return
        }
        guard questionIndex + 1 < questions.count else {
            recordAttempt(correct: questions.count)
            awarded = app.awardFishPracticeTicket(roundID: roundID)
            return
        }
        questionIndex += 1
        answer = ""
        selectedVowelIndex = nil
        selectedTone = nil
        playCurrent()
    }

    @MainActor
    private func recordAttempt(correct: Int) {
        guard var worksheet else { return }
        worksheet.attempts.append(PinyinWorksheetAttempt(id: UUID().uuidString, date: Date(), correct: correct, total: worksheet.items.count))
        self.worksheet = worksheet
        try? PinyinWorksheetStore(userID: app.currentUser.id).save(worksheet)
    }

    @MainActor
    private func playCurrent() {
        guard let current else { return }
        play(current)
    }

    @MainActor
    private func play(_ item: PinyinWorksheetItem) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            let store = try PinyinWorksheetStore(userID: app.currentUser.id)
            audioPlayer = try AVAudioPlayer(contentsOf: store.audioURL(worksheetID: worksheetID ?? "", filename: item.audioFilename))
            audioPlayer?.play()
        } catch { loadError = "录音无法播放，请联系家长检查这份听写单。" }
    }

}

private enum PinyinWorksheetOCR {
    static func recognize(_ data: Data) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(data: data, options: [:]).perform([request])
        let observations = (request.results ?? []).sorted {
            let yDelta = abs($0.boundingBox.midY - $1.boundingBox.midY)
            return yDelta > 0.018 ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX
        }
        let pattern = try NSRegularExpression(pattern: "(?i)[a-züvāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]+[1-5]?", options: [])
        var values: [String] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first?.string else { continue }
            let ns = candidate as NSString
            for match in pattern.matches(in: candidate, range: NSRange(location: 0, length: ns.length)) {
                let token = ns.substring(with: match.range).lowercased()
                let letters = token.filter(\.isLetter)
                guard (1...7).contains(letters.count), letters.contains(where: { "aeiouüv".contains($0) }) else { continue }
                values.append(token)
            }
        }
        return values
    }
}

private struct PinyinWorksheetCameraPicker: UIViewControllerRepresentable {
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
        let parent: PinyinWorksheetCameraPicker
        init(parent: PinyinWorksheetCameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
