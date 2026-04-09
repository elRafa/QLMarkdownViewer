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
