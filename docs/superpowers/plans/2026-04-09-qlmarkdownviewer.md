# QLMarkdownViewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS Quick Look generator plugin that renders `.md` and `.markdown` files as GitHub-flavored HTML with automatic light/dark mode.

**Architecture:** A `.qlgenerator` bundle with a C entry point (CFPlugIn factory) that delegates to Swift functions via `@_cdecl`. The Swift code reads Markdown, converts it to HTML with a regex-based parser, wraps it in styled HTML with embedded CSS, and returns it to Quick Look.

**Tech Stack:** Swift 6.2 (swiftc), C (clang), QuickLook/CoreFoundation frameworks, Make

---

### File Map

| File | Responsibility |
|------|---------------|
| `src/main.c` | CFPlugIn factory function, callback vtable registration |
| `src/GeneratePreviewForURL.swift` | Preview generation: read file, parse Markdown, return styled HTML |
| `src/GenerateThumbnailForURL.swift` | Thumbnail stub (no-op, returns noErr) |
| `src/MarkdownParser.swift` | Regex-based Markdown-to-HTML converter |
| `resources/Info.plist` | Bundle config, UTI declarations, plugin UUID |
| `resources/style.css` | GitHub-flavored CSS with light/dark mode |
| `Makefile` | Build, install, uninstall, clean, test targets |
| `README.md` | Usage and installation instructions |
| `LICENSE` | MIT license |
| `test/sample.md` | Test Markdown file covering all supported syntax |

---

### Task 1: Project Scaffolding and Info.plist

**Files:**
- Create: `resources/Info.plist`
- Create: `LICENSE`

- [ ] **Step 1: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>QLGenerator</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
                <string>public.markdown</string>
            </array>
        </dict>
    </array>
    <key>CFBundleExecutable</key>
    <string>QLMarkdownViewer</string>
    <key>CFBundleIdentifier</key>
    <string>com.yendigb.QLMarkdownViewer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>QLMarkdownViewer</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFPlugInDynamicRegisterFunction</key>
    <string></string>
    <key>CFPlugInDynamicRegistration</key>
    <string>NO</string>
    <key>CFPlugInFactories</key>
    <dict>
        <key>CE2A5E78-DA56-4FE5-A837-4DA5D1E0753C</key>
        <string>QuickLookGeneratorPluginFactory</string>
    </dict>
    <key>CFPlugInTypes</key>
    <dict>
        <key>5E2D9680-5022-40FA-B806-43349622E5B9</key>
        <array>
            <string>CE2A5E78-DA56-4FE5-A837-4DA5D1E0753C</string>
        </array>
    </dict>
    <key>CFPlugInUnloadFunction</key>
    <string></string>
    <key>QLNeedsToBeRunInMainThread</key>
    <false/>
    <key>QLPreviewHeight</key>
    <real>600</real>
    <key>QLPreviewWidth</key>
    <real>800</real>
    <key>QLSupportsConcurrentRequests</key>
    <true/>
    <key>QLSupportedContentTypes</key>
    <array>
        <string>net.daringfireball.markdown</string>
        <string>public.markdown</string>
    </array>
</dict>
</plist>
```

Notes:
- `CFPlugInTypes` key `5E2D9680-5022-40FA-B806-43349622E5B9` is the standard Quick Look Generator type UUID (same for all QL generators).
- `CFPlugInFactories` key `CE2A5E78-DA56-4FE5-A837-4DA5D1E0753C` is our unique factory UUID. This must match the UUID in `main.c`.

- [ ] **Step 2: Create LICENSE**

```
MIT License

Copyright (c) 2026 YendiGB

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Commit**

```bash
git add resources/Info.plist LICENSE
git commit -m "feat: add Info.plist with UTI declarations and MIT license"
```

---

### Task 2: C Plugin Entry Point

**Files:**
- Create: `src/main.c`

- [ ] **Step 1: Create main.c with CFPlugIn factory**

This file implements the standard Quick Look generator plugin boilerplate. It defines the factory function that Quick Look calls to instantiate our plugin, and a vtable that routes `GeneratePreviewForURL` and `GenerateThumbnailForURL` to our Swift implementations.

```c
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

// Forward declarations for Swift functions (linked via @_cdecl)
extern OSStatus GeneratePreviewForURL_Swift(void *thisInterface,
                                            QLPreviewRequestRef preview,
                                            CFURLRef url,
                                            CFStringRef contentTypeUTI,
                                            CFDictionaryRef options);

extern OSStatus GenerateThumbnailForURL_Swift(void *thisInterface,
                                              QLThumbnailRequestRef thumbnail,
                                              CFURLRef url,
                                              CFStringRef contentTypeUTI,
                                              CFDictionaryRef options);

// Our unique factory UUID — must match Info.plist CFPlugInFactories key
#define PLUGIN_ID CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR("CE2A5E78-DA56-4FE5-A837-4DA5D1E0753C"))

// Standard QL generator type UUID (same for all QL generators)
#define QL_GENERATOR_TYPE CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR("5E2D9680-5022-40FA-B806-43349622E5B9"))

// Plugin instance structure
typedef struct {
    void *conduitInterface;
    CFUUIDRef factoryID;
    UInt32 refCount;
} QuickLookGeneratorPluginType;

// Forward declarations
static QuickLookGeneratorPluginType *AllocQuickLookGeneratorPluginType(CFUUIDRef inFactoryID);
static void DeallocQuickLookGeneratorPluginType(QuickLookGeneratorPluginType *thisInstance);
static HRESULT QueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv);
static ULONG AddRef(void *thisInstance);
static ULONG Release(void *thisInstance);

// IUnknown vtable + QL callbacks
static QLGeneratorInterfaceStruct myInterfaceFtbl = {
    NULL,                              // padding
    QueryInterface,                    // QueryInterface
    AddRef,                           // AddRef
    Release,                          // Release
    GeneratePreviewForURL_Swift,      // GeneratePreviewForURL
    GenerateThumbnailForURL_Swift     // GenerateThumbnailForURL
};

// Allocate a new plugin instance
static QuickLookGeneratorPluginType *AllocQuickLookGeneratorPluginType(CFUUIDRef inFactoryID) {
    QuickLookGeneratorPluginType *theNewInstance = (QuickLookGeneratorPluginType *)malloc(sizeof(QuickLookGeneratorPluginType));
    memset(theNewInstance, 0, sizeof(QuickLookGeneratorPluginType));
    theNewInstance->conduitInterface = &myInterfaceFtbl;
    theNewInstance->factoryID = CFRetain(inFactoryID);
    CFPlugInAddInstanceForFactory(inFactoryID);
    theNewInstance->refCount = 1;
    return theNewInstance;
}

// Deallocate plugin instance
static void DeallocQuickLookGeneratorPluginType(QuickLookGeneratorPluginType *thisInstance) {
    CFUUIDRef theFactoryID = thisInstance->factoryID;
    free(thisInstance);
    if (theFactoryID) {
        CFPlugInRemoveInstanceForFactory(theFactoryID);
        CFRelease(theFactoryID);
    }
}

// IUnknown::QueryInterface
static HRESULT QueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv) {
    CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, iid);
    if (CFEqual(interfaceID, kQLGeneratorCallbacksInterfaceID)) {
        ((QuickLookGeneratorPluginType *)thisInstance)->conduitInterface =  &myInterfaceFtbl;
        AddRef(thisInstance);
        *ppv = thisInstance;
        CFRelease(interfaceID);
        return S_OK;
    }
    if (CFEqual(interfaceID, IUnknownUUID)) {
        ((QuickLookGeneratorPluginType *)thisInstance)->conduitInterface = &myInterfaceFtbl;
        AddRef(thisInstance);
        *ppv = thisInstance;
        CFRelease(interfaceID);
        return S_OK;
    }
    *ppv = NULL;
    CFRelease(interfaceID);
    return E_NOINTERFACE;
}

// IUnknown::AddRef
static ULONG AddRef(void *thisInstance) {
    return ++((QuickLookGeneratorPluginType *)thisInstance)->refCount;
}

// IUnknown::Release
static ULONG Release(void *thisInstance) {
    ((QuickLookGeneratorPluginType *)thisInstance)->refCount--;
    if (((QuickLookGeneratorPluginType *)thisInstance)->refCount == 0) {
        DeallocQuickLookGeneratorPluginType((QuickLookGeneratorPluginType *)thisInstance);
        return 0;
    }
    return ((QuickLookGeneratorPluginType *)thisInstance)->refCount;
}

// Factory function — called by Quick Look to create plugin instance
// This is the entry point declared in Info.plist CFPlugInFactories
void *QuickLookGeneratorPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeID) {
    if (CFEqual(typeID, QL_GENERATOR_TYPE)) {
        return AllocQuickLookGeneratorPluginType(PLUGIN_ID);
    }
    return NULL;
}
```

- [ ] **Step 2: Verify it compiles**

```bash
clang -c -o build/main.o src/main.c -framework CoreFoundation -framework CoreServices -framework QuickLook
```

Expected: compiles with no errors (warnings about unused parameters are OK).

- [ ] **Step 3: Commit**

```bash
git add src/main.c
git commit -m "feat: add C plugin entry point with CFPlugIn factory"
```

---

### Task 3: CSS Stylesheet

**Files:**
- Create: `resources/style.css`

- [ ] **Step 1: Create GitHub-flavored CSS with light/dark mode**

```css
:root {
    color-scheme: light dark;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
    font-size: 16px;
    line-height: 1.5;
    word-wrap: break-word;
    max-width: 980px;
    margin: 0 auto;
    padding: 32px;
}

/* Light mode (default) */
body {
    color: #1f2328;
    background-color: #ffffff;
}

a {
    color: #0969da;
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

h1, h2, h3, h4, h5, h6 {
    margin-top: 24px;
    margin-bottom: 16px;
    font-weight: 600;
    line-height: 1.25;
}

h1 {
    font-size: 2em;
    padding-bottom: 0.3em;
    border-bottom: 1px solid #d1d9e0;
}

h2 {
    font-size: 1.5em;
    padding-bottom: 0.3em;
    border-bottom: 1px solid #d1d9e0;
}

h3 { font-size: 1.25em; }
h4 { font-size: 1em; }
h5 { font-size: 0.875em; }
h6 { font-size: 0.85em; color: #656d76; }

p {
    margin-top: 0;
    margin-bottom: 16px;
}

code {
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
    font-size: 85%;
    padding: 0.2em 0.4em;
    margin: 0;
    background-color: rgba(175, 184, 193, 0.2);
    border-radius: 6px;
}

pre {
    margin-top: 0;
    margin-bottom: 16px;
    padding: 16px;
    overflow: auto;
    font-size: 85%;
    line-height: 1.45;
    background-color: #f6f8fa;
    border-radius: 6px;
}

pre code {
    padding: 0;
    margin: 0;
    background-color: transparent;
    border-radius: 0;
    font-size: 100%;
}

blockquote {
    margin: 0 0 16px 0;
    padding: 0 1em;
    color: #656d76;
    border-left: 0.25em solid #d1d9e0;
}

ul, ol {
    margin-top: 0;
    margin-bottom: 16px;
    padding-left: 2em;
}

li + li {
    margin-top: 0.25em;
}

table {
    border-spacing: 0;
    border-collapse: collapse;
    margin-top: 0;
    margin-bottom: 16px;
    display: block;
    width: max-content;
    max-width: 100%;
    overflow: auto;
}

table th, table td {
    padding: 6px 13px;
    border: 1px solid #d1d9e0;
}

table th {
    font-weight: 600;
    background-color: #f6f8fa;
}

table tr:nth-child(2n) {
    background-color: #f6f8fa;
}

hr {
    height: 0.25em;
    padding: 0;
    margin: 24px 0;
    background-color: #d1d9e0;
    border: 0;
}

img {
    max-width: 100%;
    box-sizing: border-box;
}

.task-list-item {
    list-style-type: none;
    margin-left: -1.5em;
}

.task-list-item input[type="checkbox"] {
    margin-right: 0.5em;
    vertical-align: middle;
}

del {
    text-decoration: line-through;
}

/* Dark mode */
@media (prefers-color-scheme: dark) {
    body {
        color: #e6edf3;
        background-color: #0d1117;
    }

    a {
        color: #4493f8;
    }

    h1, h2 {
        border-bottom-color: #3d444d;
    }

    h6 {
        color: #9198a1;
    }

    code {
        background-color: rgba(110, 118, 129, 0.4);
    }

    pre {
        background-color: #161b22;
    }

    blockquote {
        color: #9198a1;
        border-left-color: #3d444d;
    }

    table th, table td {
        border-color: #3d444d;
    }

    table th {
        background-color: #161b22;
    }

    table tr:nth-child(2n) {
        background-color: #161b22;
    }

    hr {
        background-color: #3d444d;
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add resources/style.css
git commit -m "feat: add GitHub-flavored CSS with light/dark mode support"
```

---

### Task 4: Markdown Parser

**Files:**
- Create: `src/MarkdownParser.swift`

- [ ] **Step 1: Create the Markdown-to-HTML converter**

```swift
import Foundation

struct MarkdownParser {
    static func toHTML(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        var html = ""
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Fenced code block
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let langAttr = lang.isEmpty ? "" : " class=\"language-\(escapeHTML(lang))\""
                html += "<pre><code\(langAttr)>"
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    html += escapeHTML(lines[i]) + "\n"
                    i += 1
                }
                html += "</code></pre>\n"
                i += 1
                continue
            }

            // Heading
            if let match = line.range(of: #"^(#{1,6})\s+(.+)$"#, options: .regularExpression) {
                let full = String(line[match])
                let hashCount = full.prefix(while: { $0 == "#" }).count
                let content = String(full.drop(while: { $0 == "#" }).dropFirst())
                html += "<h\(hashCount)>\(inlineMarkdown(content))</h\(hashCount)>\n"
                i += 1
                continue
            }

            // Horizontal rule
            if line.range(of: #"^(\*{3,}|-{3,}|_{3,})\s*$"#, options: .regularExpression) != nil {
                html += "<hr>\n"
                i += 1
                continue
            }

            // Table
            if i + 1 < lines.count &&
               lines[i].contains("|") &&
               lines[i + 1].range(of: #"^\|?[\s\-:|]+\|"#, options: .regularExpression) != nil {
                html += parseTable(&lines, &i)
                continue
            }

            // Blockquote
            if line.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count && (lines[i].hasPrefix(">") || (lines[i].trimmingCharacters(in: .whitespaces).isEmpty == false && !lines[i].isEmpty && i > 0 && lines[i - 1].hasPrefix(">"))) {
                    let stripped = lines[i].hasPrefix("> ") ? String(lines[i].dropFirst(2)) :
                                   lines[i].hasPrefix(">") ? String(lines[i].dropFirst(1)) : lines[i]
                    quoteLines.append(stripped)
                    i += 1
                }
                let inner = MarkdownParser.toHTML(quoteLines.joined(separator: "\n"))
                html += "<blockquote>\n\(inner)</blockquote>\n"
                continue
            }

            // Unordered list
            if line.range(of: #"^[\s]*[-*+]\s+"#, options: .regularExpression) != nil {
                html += parseUnorderedList(&lines, &i)
                continue
            }

            // Ordered list
            if line.range(of: #"^[\s]*\d+\.\s+"#, options: .regularExpression) != nil {
                html += parseOrderedList(&lines, &i)
                continue
            }

            // Empty line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }

            // Paragraph
            var paraLines: [String] = []
            while i < lines.count &&
                  !lines[i].trimmingCharacters(in: .whitespaces).isEmpty &&
                  !lines[i].hasPrefix("#") &&
                  !lines[i].hasPrefix("```") &&
                  !lines[i].hasPrefix(">") &&
                  lines[i].range(of: #"^[-*+]\s+"#, options: .regularExpression) == nil &&
                  lines[i].range(of: #"^\d+\.\s+"#, options: .regularExpression) == nil &&
                  lines[i].range(of: #"^(\*{3,}|-{3,}|_{3,})\s*$"#, options: .regularExpression) == nil {
                paraLines.append(lines[i])
                i += 1
            }
            if !paraLines.isEmpty {
                html += "<p>\(inlineMarkdown(paraLines.joined(separator: "\n")))</p>\n"
            }
        }

        return html
    }

    // MARK: - Block Parsers

    private static func parseTable(_ lines: inout [String], _ i: inout Int) -> String {
        var html = "<table>\n"

        // Header row
        let headerCells = parsePipeLine(lines[i])
        html += "<thead><tr>\n"
        for cell in headerCells {
            html += "<th>\(inlineMarkdown(cell))</th>\n"
        }
        html += "</tr></thead>\n"
        i += 1

        // Separator row (skip)
        i += 1

        // Body rows
        html += "<tbody>\n"
        while i < lines.count && lines[i].contains("|") {
            let cells = parsePipeLine(lines[i])
            html += "<tr>\n"
            for cell in cells {
                html += "<td>\(inlineMarkdown(cell))</td>\n"
            }
            html += "</tr>\n"
            i += 1
        }
        html += "</tbody>\n</table>\n"
        return html
    }

    private static func parsePipeLine(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed = String(trimmed.dropFirst()) }
        if trimmed.hasSuffix("|") { trimmed = String(trimmed.dropLast()) }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseUnorderedList(_ lines: inout [String], _ i: inout Int) -> String {
        var html = "<ul>\n"
        while i < lines.count && lines[i].range(of: #"^[\s]*[-*+]\s+"#, options: .regularExpression) != nil {
            let content = lines[i].replacingOccurrences(of: #"^[\s]*[-*+]\s+"#, with: "", options: .regularExpression)
            // Task list item
            if content.hasPrefix("[ ] ") {
                html += "<li class=\"task-list-item\"><input type=\"checkbox\" disabled> \(inlineMarkdown(String(content.dropFirst(4))))</li>\n"
            } else if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
                html += "<li class=\"task-list-item\"><input type=\"checkbox\" checked disabled> \(inlineMarkdown(String(content.dropFirst(4))))</li>\n"
            } else {
                html += "<li>\(inlineMarkdown(content))</li>\n"
            }
            i += 1
        }
        html += "</ul>\n"
        return html
    }

    private static func parseOrderedList(_ lines: inout [String], _ i: inout Int) -> String {
        var html = "<ol>\n"
        while i < lines.count && lines[i].range(of: #"^[\s]*\d+\.\s+"#, options: .regularExpression) != nil {
            let content = lines[i].replacingOccurrences(of: #"^[\s]*\d+\.\s+"#, with: "", options: .regularExpression)
            html += "<li>\(inlineMarkdown(content))</li>\n"
            i += 1
        }
        html += "</ol>\n"
        return html
    }

    // MARK: - Inline Markdown

    static func inlineMarkdown(_ text: String) -> String {
        var result = escapeHTML(text)

        // Inline code (must be first to prevent inner processing)
        result = replacePattern(result, #"`([^`]+)`"#) { match, groups in
            "<code>\(groups[0])</code>"
        }

        // Images
        result = replacePattern(result, #"!\[([^\]]*)\]\(([^)]+)\)"#) { match, groups in
            "<img src=\"\(groups[1])\" alt=\"\(groups[0])\">"
        }

        // Links
        result = replacePattern(result, #"\[([^\]]+)\]\(([^)]+)\)"#) { match, groups in
            "<a href=\"\(groups[1])\">\(groups[0])</a>"
        }

        // Bold + italic
        result = replacePattern(result, #"\*\*\*(.+?)\*\*\*"#) { _, groups in
            "<strong><em>\(groups[0])</em></strong>"
        }

        // Bold
        result = replacePattern(result, #"\*\*(.+?)\*\*"#) { _, groups in
            "<strong>\(groups[0])</strong>"
        }

        // Italic
        result = replacePattern(result, #"\*(.+?)\*"#) { _, groups in
            "<em>\(groups[0])</em>"
        }

        // Strikethrough
        result = replacePattern(result, #"~~(.+?)~~"#) { _, groups in
            "<del>\(groups[0])</del>"
        }

        // Line breaks
        result = result.replacingOccurrences(of: "\n", with: "<br>\n")

        return result
    }

    // MARK: - Utilities

    static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func replacePattern(_ text: String, _ pattern: String, _ replacement: (String, [String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let nsText = text as NSString
        var result = text
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        // Process in reverse to preserve ranges
        for match in matches.reversed() {
            let fullMatch = nsText.substring(with: match.range)
            var groups: [String] = []
            for g in 1..<match.numberOfRanges {
                if match.range(at: g).location != NSNotFound {
                    groups.append(nsText.substring(with: match.range(at: g)))
                }
            }
            let replacementStr = replacement(fullMatch, groups)
            let startIndex = result.index(result.startIndex, offsetBy: match.range.location)
            let endIndex = result.index(startIndex, offsetBy: match.range.length)
            result.replaceSubrange(startIndex..<endIndex, with: replacementStr)
        }
        return result
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
swiftc -parse-as-library -typecheck src/MarkdownParser.swift
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add src/MarkdownParser.swift
git commit -m "feat: add regex-based Markdown-to-HTML parser with GFM support"
```

---

### Task 5: Preview and Thumbnail Generation

**Files:**
- Create: `src/GeneratePreviewForURL.swift`
- Create: `src/GenerateThumbnailForURL.swift`

- [ ] **Step 1: Create GenerateThumbnailForURL.swift (stub)**

```swift
import Foundation
import QuickLook

@_cdecl("GenerateThumbnailForURL_Swift")
public func generateThumbnail(
    thisInterface: UnsafeMutableRawPointer?,
    thumbnail: QLThumbnailRequestRef,
    url: CFURLRef,
    contentTypeUTI: CFString?,
    options: CFDictionary?
) -> OSStatus {
    return OSStatus(noErr)
}
```

- [ ] **Step 2: Create GeneratePreviewForURL.swift**

This reads the CSS from the bundle's Resources directory, reads the Markdown file, converts to HTML, wraps in a styled template, and returns it.

```swift
import Foundation
import QuickLook

@_cdecl("GeneratePreviewForURL_Swift")
public func generatePreview(
    thisInterface: UnsafeMutableRawPointer?,
    preview: QLPreviewRequestRef,
    url: CFURLRef,
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
    let bundle = QLPreviewRequestGetGeneratorBundle(preview)
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
```

- [ ] **Step 3: Verify all Swift files compile together**

```bash
swiftc -parse-as-library -typecheck -framework QuickLook -framework CoreServices src/MarkdownParser.swift src/GeneratePreviewForURL.swift src/GenerateThumbnailForURL.swift
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add src/GeneratePreviewForURL.swift src/GenerateThumbnailForURL.swift
git commit -m "feat: add preview and thumbnail generation with HTML rendering"
```

---

### Task 6: Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Create Makefile**

```makefile
BUNDLE_NAME = QLMarkdownViewer
BUNDLE = $(BUNDLE_NAME).qlgenerator
BUILD_DIR = build
INSTALL_DIR = $(HOME)/Library/QuickLook

SWIFT_FILES = src/MarkdownParser.swift src/GeneratePreviewForURL.swift src/GenerateThumbnailForURL.swift
C_FILES = src/main.c

SWIFT_FLAGS = -parse-as-library -O -module-name $(BUNDLE_NAME) -emit-library \
	-framework QuickLook -framework CoreServices -framework CoreFoundation

C_FLAGS = -framework CoreFoundation -framework CoreServices -framework QuickLook

.PHONY: build install uninstall clean test

build: clean
	@echo "Building $(BUNDLE)..."
	@mkdir -p $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUILD_DIR)/$(BUNDLE)/Contents/Resources

	# Compile Swift sources into a dynamic library
	swiftc $(SWIFT_FLAGS) \
		-o $(BUILD_DIR)/lib$(BUNDLE_NAME).dylib \
		$(SWIFT_FILES)

	# Compile C entry point and link with Swift library
	clang $(C_FLAGS) \
		-L$(BUILD_DIR) -l$(BUNDLE_NAME) \
		-Xlinker -rpath -Xlinker @loader_path \
		-bundle \
		-o $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS/$(BUNDLE_NAME) \
		$(C_FILES)

	# Copy dylib into bundle
	@cp $(BUILD_DIR)/lib$(BUNDLE_NAME).dylib $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS/

	# Copy resources
	@cp resources/Info.plist $(BUILD_DIR)/$(BUNDLE)/Contents/
	@cp resources/style.css $(BUILD_DIR)/$(BUNDLE)/Contents/Resources/

	@echo "Build complete: $(BUILD_DIR)/$(BUNDLE)"

install: build
	@echo "Installing to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@rm -rf $(INSTALL_DIR)/$(BUNDLE)
	@cp -R $(BUILD_DIR)/$(BUNDLE) $(INSTALL_DIR)/
	@qlmanage -r 2>/dev/null || true
	@echo "Installed. Quick Look plugins reloaded."

uninstall:
	@echo "Uninstalling $(BUNDLE)..."
	@rm -rf $(INSTALL_DIR)/$(BUNDLE)
	@qlmanage -r 2>/dev/null || true
	@echo "Uninstalled."

clean:
	@rm -rf $(BUILD_DIR)

test: install
	@echo "Testing Quick Look preview..."
	@qlmanage -p test/sample.md
```

- [ ] **Step 2: Commit**

```bash
git add Makefile
git commit -m "feat: add Makefile with build, install, uninstall, and test targets"
```

---

### Task 7: Test File and README

**Files:**
- Create: `test/sample.md`
- Create: `README.md`

- [ ] **Step 1: Create test Markdown file**

```markdown
# QLMarkdownViewer Test Document

This file tests all supported Markdown features.

## Text Formatting

This is **bold text**, this is *italic text*, and this is ***bold italic***.

Here is some ~~strikethrough~~ text and `inline code`.

## Links and Images

[Visit GitHub](https://github.com)

![Alt text](https://via.placeholder.com/150)

## Code Block

```python
def hello():
    print("Hello, World!")
    return 42
```

## Blockquote

> This is a blockquote.
> It can span multiple lines.

## Lists

### Unordered

- Item one
- Item two
- Item three

### Ordered

1. First item
2. Second item
3. Third item

### Task List

- [x] Completed task
- [ ] Incomplete task
- [x] Another completed task

## Table

| Feature | Status | Notes |
|---------|--------|-------|
| Headings | Done | h1-h6 |
| Bold/Italic | Done | GFM style |
| Code blocks | Done | With language class |
| Tables | Done | Pipe syntax |

## Horizontal Rule

---

## Nested Content

> Blockquote with **bold** and `code` inside.

A paragraph with [a link](https://example.com) and **bold *nested italic* text**.
```

- [ ] **Step 2: Create README.md**

```markdown
# QLMarkdownViewer

A macOS Quick Look plugin that renders Markdown files (.md, .markdown) as styled HTML when you press Space in Finder.

## Features

- GitHub-flavored Markdown rendering
- Automatic light/dark mode support
- Headings, bold, italic, strikethrough, inline code
- Fenced code blocks with language detection
- Tables, task lists, blockquotes
- Links, images, horizontal rules
- No runtime dependencies

## Requirements

- macOS 13+
- Swift (via Xcode Command Line Tools)

## Installation

```bash
git clone https://github.com/YendiGB/QLMarkdownViewer.git
cd QLMarkdownViewer
make install
```

## Uninstall

```bash
make uninstall
```

## Usage

After installation, select any `.md` or `.markdown` file in Finder and press Space to see the rendered preview.

## Build Only

```bash
make build
```

The built plugin will be at `build/QLMarkdownViewer.qlgenerator`.

## License

MIT
```

- [ ] **Step 3: Commit**

```bash
git add test/sample.md README.md
git commit -m "feat: add test file and README"
```

---

### Task 8: Build, Test, and Fix

- [ ] **Step 1: Run the full build**

```bash
make build
```

Expected: "Build complete: build/QLMarkdownViewer.qlgenerator"

- [ ] **Step 2: Verify bundle structure**

```bash
find build/QLMarkdownViewer.qlgenerator -type f
```

Expected output:
```
build/QLMarkdownViewer.qlgenerator/Contents/Info.plist
build/QLMarkdownViewer.qlgenerator/Contents/MacOS/QLMarkdownViewer
build/QLMarkdownViewer.qlgenerator/Contents/MacOS/libQLMarkdownViewer.dylib
build/QLMarkdownViewer.qlgenerator/Contents/Resources/style.css
```

- [ ] **Step 3: Install and test**

```bash
make install
qlmanage -p test/sample.md
```

Expected: Quick Look preview window opens showing rendered Markdown.

- [ ] **Step 4: Fix any build or runtime errors**

If the build fails, check compiler output and fix. Common issues:
- Missing framework imports: add `-framework` flags
- Swift/C linking issues: check `@_cdecl` function names match C `extern` declarations
- UTI not recognized: verify Info.plist UTI strings

- [ ] **Step 5: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve build/runtime issues"
```

---

### Task 9: Create GitHub Repository

- [ ] **Step 1: Create .gitignore**

```
build/
.DS_Store
*.o
*.dylib
```

- [ ] **Step 2: Create private GitHub repo and push**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
gh repo create YendiGB/QLMarkdownViewer --private --source=. --push
```

Expected: repo created and code pushed.

- [ ] **Step 3: Verify repo**

```bash
gh repo view YendiGB/QLMarkdownViewer
```
