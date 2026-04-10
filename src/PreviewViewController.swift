import Cocoa
import Quartz
import UniformTypeIdentifiers

class PreviewProvider: NSViewController, QLPreviewingController {

    override func loadView() {
        self.view = NSView()
    }

    func providePreview(for request: QLFilePreviewRequest, completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        do {
            let data = try Data(contentsOf: request.fileURL)
            let markdown = String(data: data, encoding: .utf8) ?? ""

            // Load CSS from extension bundle
            var css = ""
            if let cssURL = Bundle.main.url(forResource: "style", withExtension: "css") {
                css = (try? String(contentsOf: cssURL, encoding: .utf8)) ?? ""
            }

            let body = MarkdownParser.toHTML(markdown)

            let html = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>\(css)</style>
            </head>
            <body>
            \(body)
            </body>
            </html>
            """

            let reply = QLPreviewReply(dataOfContentType: UTType.html, contentSize: CGSize(width: 800, height: 800)) { _ in
                return html.data(using: .utf8)!
            }

            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }
}
