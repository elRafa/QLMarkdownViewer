import Cocoa
import Quartz
import UniformTypeIdentifiers
import OSLog

private let log = Logger(subsystem: "com.yendigb.QLMarkdownViewer", category: "preview")

class PreviewProvider: NSViewController, QLPreviewingController {

    override func loadView() {
        self.view = NSView()
    }

    func providePreview(for request: QLFilePreviewRequest, completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        log.info("providePreview called for: \(request.fileURL.path, privacy: .public)")
        do {
            let data = try Data(contentsOf: request.fileURL)
            let markdown = String(data: data, encoding: .utf8) ?? ""

            var css = ""
            if let cssURL = Bundle.main.url(forResource: "style", withExtension: "css") {
                css = (try? String(contentsOf: cssURL, encoding: .utf8)) ?? ""
            }

            let body = MarkdownParser.toHTML(markdown)
            let baseDir = request.fileURL.deletingLastPathComponent()
            let bodyWithResolvedImages = Self.inlineImages(in: body, baseDir: baseDir)

            let html = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="color-scheme" content="light dark">
            <style>\(css)</style>
            </head>
            <body>
            \(bodyWithResolvedImages)
            </body>
            </html>
            """

            log.info("providePreview built html, bytes=\(html.utf8.count) bodyLen=\(bodyWithResolvedImages.count)")
            // Use dataOfContentType so Quick Look hosts the HTML in its own
            // WebView context — sub-resource fetches (remote images) work
            // without the extension's sandbox-tmp file:// origin getting in
            // the way. Link clicks still open in the default browser via the
            // host WebView's default navigation behavior.
            let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 800, height: 600)) { reply in
                reply.stringEncoding = .utf8
                return html.data(using: .utf8) ?? Data()
            }
            handler(reply, nil)
        } catch {
            log.error("providePreview failed: \(error.localizedDescription, privacy: .public)")
            handler(nil, error)
        }
    }

    /// Inlines local relative images as base64 data: URIs. Remote http(s)
    /// images are left as-is for QL's host WebView to fetch — keeping the
    /// extension out of the network path also closes the SSRF surface that
    /// would otherwise let a malicious .md probe loopback / cloud-metadata
    /// hosts. On any failure we leave the tag alone.
    static func inlineImages(in html: String, baseDir: URL) -> String {
        let pattern = #"<img[^>]*\ssrc="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }

        let mutable = NSMutableString(string: html)
        let matches = regex.matches(in: mutable as String, options: [], range: NSRange(location: 0, length: mutable.length))
        let baseDirResolved = baseDir.standardizedFileURL.resolvingSymlinksInPath().path
        let basePrefix = baseDirResolved.hasSuffix("/") ? baseDirResolved : baseDirResolved + "/"

        for match in matches.reversed() {
            let srcRange = match.range(at: 1)
            let src = mutable.substring(with: srcRange)

            // Don't touch already-inlined, anchor-style, or remote sources.
            if src.hasPrefix("data:") || src.hasPrefix("cid:") { continue }
            if src.hasPrefix("http://") || src.hasPrefix("https://") { continue }

            // Reject absolute filesystem paths and file:// — only relative
            // references (resolved against baseDir) are permitted, so a
            // crafted ![](/etc/passwd) can't exfiltrate via the rendered HTML.
            if src.hasPrefix("/") || src.lowercased().hasPrefix("file:") { continue }

            let imageURL = baseDir.appendingPathComponent(src)
            let resolved = imageURL.standardizedFileURL.resolvingSymlinksInPath().path
            // Containment: the resolved path must be inside baseDir.
            // Defends against ![](../../../some/other/file).
            guard resolved.hasPrefix(basePrefix) else { continue }

            guard let imageData = try? Data(contentsOf: imageURL) else { continue }
            let mimeType = mimeType(forExtension: imageURL.pathExtension)
            let dataURI = "data:\(mimeType);base64,\(imageData.base64EncodedString())"
            mutable.replaceCharacters(in: srcRange, with: dataURI)
        }

        return mutable as String
    }

    private static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "heic": return "image/heic"
        case "tif", "tiff": return "image/tiff"
        default: return "application/octet-stream"
        }
    }
}
