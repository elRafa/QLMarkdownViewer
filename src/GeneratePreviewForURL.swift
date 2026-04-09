import Foundation
import QuickLook
import CoreServices

@_cdecl("GeneratePreviewForURL_Swift")
public func generatePreview(
    thisInterface: UnsafeMutableRawPointer?,
    preview: QLPreviewRequest,
    url: CFURL,
    contentTypeUTI: CFString?,
    options: CFDictionary?
) -> OSStatus {
    let fileURL = url as URL

    // Read Markdown file
    guard let markdownData = try? Data(contentsOf: fileURL),
          let markdown = String(data: markdownData, encoding: .utf8) else {
        return OSStatus(noErr)
    }

    // Load CSS from bundle resources
    var css = ""
    let bundle = QLPreviewRequestGetGeneratorBundle(preview)?.takeRetainedValue()
    if let cssURL = CFBundleCopyResourceURL(bundle, "style" as CFString, "css" as CFString, nil) {
        if let cssData = try? Data(contentsOf: cssURL as URL),
           let cssString = String(data: cssData, encoding: .utf8) {
            css = cssString
        }
    }

    // Convert Markdown to HTML
    let body = MarkdownParser.toHTML(markdown)

    // Build full HTML document
    let html = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>\(css)</style>
    </head>
    <body>
    \(body)
    </body>
    </html>
    """

    guard let htmlData = html.data(using: .utf8) else {
        return OSStatus(noErr)
    }

    // Check if preview was cancelled
    if QLPreviewRequestIsCancelled(preview) {
        return OSStatus(noErr)
    }

    // Set preview data as HTML
    let properties: CFDictionary = [
        kQLPreviewPropertyMIMETypeKey: "text/html" as CFString,
        kQLPreviewPropertyTextEncodingNameKey: "UTF-8" as CFString
    ] as CFDictionary

    QLPreviewRequestSetDataRepresentation(
        preview,
        htmlData as CFData,
        kUTTypeHTML,
        properties
    )

    return OSStatus(noErr)
}
