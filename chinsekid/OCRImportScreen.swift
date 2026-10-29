import CoreFoundation
import PhotosUI
import SwiftUI
import UIKit
import Vision

private enum ImportPickerSheet: String, Identifiable {
    case photoLibrary
    case camera

    var id: String { rawValue }
}

private enum ImportPalette {
    static let ink = KidsTheme.ink
    static let muted = KidsTheme.muted
    static let paper = KidsTheme.paper
    static let mint = KidsTheme.mint
    static let orange = KidsTheme.orange
    static let yellow = KidsTheme.yellow
}

struct OCRImportScreen: View {
    let app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var activePickerSheet: ImportPickerSheet?
    @State private var capturedImage: UIImage?
    @State private var foundCharacters: [String] = []
    @State private var selectedCharacters = Set<String>()
    @State private var isRecognizing = false
    @State private var notice: String?
    @State private var importedResult: (added: Int, existing: Int)?
    @State private var ocr = OCRService()

    private let columns = [GridItem(.adaptive(minimum: 62), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 21) {
                    intro
                    sourceActions
                    if isRecognizing {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("正在找汉字宝藏…")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(ImportPalette.ink)
                        .frame(maxWidth: .infinity).padding(24)
                        .background(.white, in: RoundedRectangle(cornerRadius: 22))
                    }
                    if !foundCharacters.isEmpty {
                        resultsSection
                    } else if let notice {
                        Text(notice)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(ImportPalette.ink)
                            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(ImportPalette.yellow.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
                    }
                    if let importedResult {
                        successBanner(importedResult)
                    }
                }
                .padding(22)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background { StorybookBackground() }
            .navigationTitle("发现新汉字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .sheet(item: $activePickerSheet, onDismiss: processCapturedImage) { pickerSheet in
                Group {
                    switch pickerSheet {
                    case .photoLibrary:
                        PhotoLibraryPicker { data in
                            activePickerSheet = nil
                            guard let data else { return }
                            Task { await recognize(data: data) }
                        }
                        .ignoresSafeArea()
                    case .camera:
                        CameraPicker(image: $capturedImage)
                            .ignoresSafeArea()
                    }
                }
                .interactiveDismissDisabled()
            }
            .alert("没有找到汉字", isPresented: Binding(
                get: { notice != nil && foundCharacters.isEmpty && !isRecognizing },
                set: { if !$0 { notice = nil } }
            )) {
                Button("再试一次", role: .cancel) { notice = nil }
            } message: {
                Text(notice ?? "可以把照片拍清楚一些再试试。")
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("📸  把身边的汉字收进图鉴")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(ImportPalette.ink)
            Text("拍绘本、路牌或包装上的字，选出你想认识的汉字。照片识别后不会保存。")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(ImportPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sourceActions: some View {
        HStack(spacing: 12) {
            Button {
                activePickerSheet = .photoLibrary
            } label: {
                sourceCard(title: "从相册选", subtitle: "挑一张照片", icon: "photo.on.rectangle.angled", color: ImportPalette.mint)
            }
            .buttonStyle(.plain)
            Button {
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    notice = "当前设备没有可用的相机，可以从相册选一张照片。"
                    return
                }
                activePickerSheet = .camera
            } label: {
                sourceCard(title: "现在拍照", subtitle: "对准汉字拍", icon: "camera.fill", color: ImportPalette.yellow)
            }
            .buttonStyle(.plain)
        }
    }

    private func sourceCard(title: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Image(systemName: icon).font(.system(size: 25, weight: .bold))
            Text(title).font(.system(size: 16, weight: .heavy, design: .rounded))
            Text(subtitle).font(.system(size: 12, weight: .medium, design: .rounded)).opacity(0.72)
        }
        .foregroundStyle(ImportPalette.ink)
        .frame(maxWidth: .infinity, minHeight: 115, alignment: .leading)
        .padding(15)
        .background(color, in: RoundedRectangle(cornerRadius: 23))
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("找到 \(foundCharacters.count) 个字")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(ImportPalette.ink)
                    Text("点一点，选出要收集的汉字")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(ImportPalette.muted)
                }
                Spacer()
                Button(selectedCharacters.count == foundCharacters.count ? "全不选" : "全选") {
                    if selectedCharacters.count == foundCharacters.count {
                        selectedCharacters.removeAll()
                    } else {
                        selectedCharacters = Set(foundCharacters)
                    }
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(foundCharacters.enumerated()), id: \.element) { index, glyph in
                    let selected = selectedCharacters.contains(glyph)
                    Button {
                        if selected { selectedCharacters.remove(glyph) }
                        else { selectedCharacters.insert(glyph) }
                    } label: {
                        VStack(spacing: 3) {
                            Text(glyph).font(.system(size: 31, weight: .bold, design: .serif))
                            if app.contains(glyph) {
                                Text("已收集").font(.system(size: 9, weight: .bold, design: .rounded))
                            } else {
                                Text("新发现").font(.system(size: 9, weight: .bold, design: .rounded)).opacity(0.65)
                            }
                        }
                        .foregroundStyle(ImportPalette.ink)
                        .frame(maxWidth: .infinity).frame(height: 73)
                        .background(selected ? ImportPalette.mint : tileColor(index), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(selected ? ImportPalette.ink : ImportPalette.ink.opacity(0.35))
                                .padding(6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                let result = app.importCharacters(foundCharacters.filter(selectedCharacters.contains))
                importedResult = result
                foundCharacters = []
                selectedCharacters = []
                notice = nil
            } label: {
                HStack {
                    Text("收进我的图鉴")
                    Spacer()
                    Text("\(selectedCharacters.count) 个")
                    Image(systemName: "arrow.right.circle.fill")
                }
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(ImportPalette.ink)
                .padding(.horizontal, 20).frame(height: 58)
                .background(ImportPalette.orange, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selectedCharacters.isEmpty)
            .opacity(selectedCharacters.isEmpty ? 0.5 : 1)
        }
        .padding(17)
        .background(.white, in: RoundedRectangle(cornerRadius: 25))
    }

    private func successBanner(_ result: (added: Int, existing: Int)) -> some View {
        HStack(spacing: 11) {
            Text("🎉").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 3) {
                Text(result.added > 0 ? "新汉字已经收好啦！" : "这些字已经在图鉴里啦")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Text("新收集 \(result.added) 个 · 已有 \(result.existing) 个")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            Spacer()
        }
        .foregroundStyle(ImportPalette.ink)
        .padding(16)
        .background(ImportPalette.mint, in: RoundedRectangle(cornerRadius: 21))
    }

    private func tileColor(_ index: Int) -> Color {
        [ImportPalette.yellow.opacity(0.75), ImportPalette.mint.opacity(0.72), ImportPalette.orange.opacity(0.34)][index % 3]
    }

    @MainActor
    private func recognize(data: Data) async {
        isRecognizing = true
        notice = nil
        importedResult = nil
        foundCharacters = []
        selectedCharacters.removeAll()
        defer { isRecognizing = false }
        do {
            let found = try await ocr.recognize(data: data)
            guard !found.isEmpty else {
                notice = "没有找到汉字。试试拍得更清楚、离近一点～"
                return
            }
            foundCharacters = found
            selectedCharacters.removeAll()
        } catch {
            notice = "照片识别遇到一点小问题，再试一次吧。"
        }
    }

    @MainActor
    private func processCapturedImage() {
        guard let capturedImage else { return }
        self.capturedImage = nil
        guard let data = capturedImage.jpegData(compressionQuality: 0.96) else {
            notice = "照片处理失败，可以重拍一次。"
            return
        }
        Task { await recognize(data: data) }
    }

}

private actor OCRService {
    func recognize(data: Data) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Detect text down to 0.1% of the image height; the smaller threshold
        // helps with fine print while the selection screen lets users discard
        // any extra background characters that it finds.
        request.minimumTextHeight = 0.001
        request.recognitionLanguages = ["zh-Hans"]
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(data: data, options: [:]).perform([request])
        let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
        var seen = Set<String>()
        var characters: [String] = []
        for line in lines {
            let simplifiedLine = NSMutableString(string: line)
            let didConvert = CFStringTransform(simplifiedLine, nil, "Traditional-Simplified" as CFString, false)
            let normalizedLine = didConvert ? simplifiedLine as String : line
            for character in normalizedLine {
                guard Self.isHan(character), seen.insert(String(character)).inserted else { continue }
                characters.append(String(character))
            }
        }
        return characters
    }

    private static func isHan(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else { return false }
        let value = scalar.value
        return (0x3400...0x4DBF).contains(value) || (0x4E00...0x9FFF).contains(value) || (0xF900...0xFAFF).contains(value)
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
