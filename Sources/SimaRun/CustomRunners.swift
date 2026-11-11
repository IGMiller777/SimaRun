import AppKit
import ImageIO

/// Runners made from your own images.
///
/// Put them in `~/Library/Application Support/SimaRun/Runners/`:
///   - a folder of images (`Runners/Fox/01.png`, `02.png`, …) — one runner, frames in file-name order
///   - or a single animated GIF/PNG (`Runners/Fox.gif`) — one runner, frames taken from the file
///
/// Images with a transparent background and no colour are tinted like the built-in runners
/// (white on a dark menu bar, black on a light one). Anything else is shown as it is.
enum CustomRunners {
    struct Loaded {
        var frames: [CGImage]
        var tinted: Bool
    }

    static let folder: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SimaRun/Runners", isDirectory: true)

    private static let imageExtensions: Set<String> = ["png", "gif", "jpg", "jpeg", "tiff", "tif", "heic", "webp"]
    private static let maxFrames = 120
    private static let maxPixelSize = 192 // frames are shrunk to this; plenty for a 24 pt icon on Retina

    /// Names of the runners currently in the folder, sorted for display.
    static func names(in folder: URL = folder) -> [String] {
        entries(in: folder).keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func load(name: String, in folder: URL = folder) -> Loaded? {
        guard let entry = entries(in: folder)[name] else { return nil }

        var frames: [CGImage] = []
        for file in imageFiles(of: entry) {
            guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { continue }
            for index in 0..<CGImageSourceGetCount(source) where frames.count < maxFrames {
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                ]
                if let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) {
                    frames.append(image)
                }
            }
        }
        guard let first = frames.first else { return nil }
        return Loaded(frames: frames, tinted: shouldTint(first))
    }

    // MARK: - Folder scanning

    /// Runner name -> the folder or single image file it comes from.
    private static func entries(in folder: URL) -> [String: URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        var result: [String: URL] = [:]
        for url in contents {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                result[url.lastPathComponent] = url
            } else if imageExtensions.contains(url.pathExtension.lowercased()) {
                result[url.deletingPathExtension().lastPathComponent] = url
            }
        }
        return result
    }

    private static func imageFiles(of entry: URL) -> [URL] {
        let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        guard isDirectory else { return [entry] }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return files
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    // MARK: - Tint detection

    /// True for silhouette-style art: has transparent areas and no real colour.
    private static func shouldTint(_ image: CGImage) -> Bool {
        let side = 48
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return false }

        var hasTransparency = false
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[offset]), g = Int(pixels[offset + 1]), b = Int(pixels[offset + 2])
            let alpha = Int(pixels[offset + 3])
            if alpha < 250 { hasTransparency = true }
            // Values are premultiplied, so compare the channel spread against alpha.
            if alpha > 40, (max(r, g, b) - min(r, g, b)) * 8 > alpha { return false } // coloured
        }
        return hasTransparency
    }
}
