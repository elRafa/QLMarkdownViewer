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

    /// Rewrites <img src="..."> into base64 data: URIs by fetching the image
    /// in the extension process. Local reads and remote http(s) fetches both
    /// get inlined — the QL host WebView silently drops remote requests, so
    /// we pull them ourselves. On failure we leave the tag alone.
    static func inlineImages(in html: String, baseDir: URL) -> String {
        let pattern = #"<img[^>]*\ssrc="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }

        let mutable = NSMutableString(string: html)
        let matches = regex.matches(in: mutable as String, options: [], range: NSRange(location: 0, length: mutable.length))

        for match in matches.reversed() {
            let srcRange = match.range(at: 1)
            let src = mutable.substring(with: srcRange)

            if src.hasPrefix("data:") || src.hasPrefix("cid:") {
                continue
            }

            let imageData: Data?
            let mime: String

            if src.hasPrefix("http://") || src.hasPrefix("https://"), let url = URL(string: src) {
                let fetched = fetchRemote(url: url)
                imageData = fetched.data
                mime = fetched.mime ?? mimeType(forExtension: url.pathExtension)
            } else {
                let imageURL: URL
                if src.hasPrefix("/") {
                    imageURL = URL(fileURLWithPath: src)
                } else if let u = URL(string: src), u.scheme == "file" {
                    imageURL = u
                } else {
                    imageURL = baseDir.appendingPathComponent(src)
                }
                imageData = try? Data(contentsOf: imageURL)
                mime = mimeType(forExtension: imageURL.pathExtension)
            }

            guard let data = imageData else { continue }
            let dataURI = "data:\(mime);base64,\(data.base64EncodedString())"
            mutable.replaceCharacters(in: srcRange, with: dataURI)
        }

        return mutable as String
    }

    /// providePreview runs off the main thread, so a blocking synchronous
    /// fetch keeps the inlining loop simple. Per-request timeout bounds the
    /// worst case for documents with slow or dead image hosts.
    private static func fetchRemote(url: URL) -> (data: Data?, mime: String?) {
        log.info("fetchRemote start: \(url.absoluteString, privacy: .public)")
        var result: (data: Data?, mime: String?) = (nil, nil)
        let semaphore = DispatchSemaphore(value: 0)
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                log.error("fetchRemote error: \(error.localizedDescription, privacy: .public)")
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let header = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")
            let mime = header?.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces)
            log.info("fetchRemote done: status=\(status) bytes=\(data?.count ?? -1) mime=\(mime ?? "nil", privacy: .public)")
            result = (data, mime)
            semaphore.signal()
        }
        task.resume()
        let waitResult = semaphore.wait(timeout: .now() + 12)
        if waitResult == .timedOut {
            log.error("fetchRemote timed out: \(url.absoluteString, privacy: .public)")
        }
        return result
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
