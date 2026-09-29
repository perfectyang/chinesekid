import UIKit

enum ProfileAvatarStore {
    private static let folderName = "ProfileAvatars"

    static func image(for filename: String?) -> UIImage? {
        guard let filename, URL(fileURLWithPath: filename).lastPathComponent == filename,
              let directory = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
              ) else { return nil }
        let url = directory.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    static func save(_ image: UIImage, for userID: String) throws -> String {
        let filename = "\(userID).jpg"
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let target = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let thumbnail = renderer.image { _ in
            let scale = max(target.width / image.size.width, target.height / image.size.height)
            let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(
                x: (target.width - fitted.width) / 2,
                y: (target.height - fitted.height) / 2,
                width: fitted.width,
                height: fitted.height
            ))
        }
        guard let data = thumbnail.jpegData(compressionQuality: 0.82) else {
            throw NSError(domain: "ProfileAvatarStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法处理这张头像照片"])
        }
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    static func remove(filename: String?) {
        guard let filename, URL(fileURLWithPath: filename).lastPathComponent == filename,
              let directory = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
              ) else { return }
        try? FileManager.default.removeItem(
            at: directory.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(filename)
        )
    }
}
