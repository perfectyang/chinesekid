import PhotosUI
import SwiftUI
import UIKit

struct ProfileAvatarView: View {
    let user: ChildProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let image = ProfileAvatarStore.image(for: user.avatarFilename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(KidsTheme.yellow)
                    Text(user.avatar).font(.system(size: size * 0.55))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
    }
}

struct ProfileAvatarEditor: View {
    let user: ChildProfile
    let onSave: (ChildProfile, UIImage) -> Void

    @State private var showingSourceOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var cameraUnavailable = false
    @State private var photoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?

    var body: some View {
        Button {
            showingSourceOptions = true
        } label: {
            ProfileAvatarView(user: user, size: 52)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 19, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, KidsTheme.ink)
                        .offset(x: 2, y: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("更换\(user.name)的头像")
        .confirmationDialog("更换头像", isPresented: $showingSourceOptions, titleVisibility: .visible) {
            Button("拍照") {
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    cameraUnavailable = true
                    return
                }
                showingCamera = true
            }
            Button("从相册选择") { showingPhotoPicker = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("为 \(user.name) 选一张喜欢的照片")
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .sheet(isPresented: $showingCamera) {
            ProfileCameraPicker(image: $capturedImage)
                .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        cameraUnavailable = true
                        return
                    }
                    onSave(user, image)
                    photoItem = nil
                } catch {
                    cameraUnavailable = true
                }
            }
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            onSave(user, image)
            capturedImage = nil
        }
        .alert("无法更换头像", isPresented: $cameraUnavailable) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("当前设备无法打开相机或读取照片，请再试一次。")
        }
    }
}

private struct ProfileCameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: ProfileCameraPicker

        init(_ parent: ProfileCameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
