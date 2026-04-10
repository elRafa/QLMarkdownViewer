# QLMarkdownViewer

A macOS Quick Look extension that renders Markdown files (.md, .markdown) as styled HTML when you press Space in Finder.

## Features

- GitHub-flavored Markdown rendering
- Automatic light/dark mode support
- Headings, bold, italic, strikethrough, inline code
- Fenced code blocks with language detection
- Tables, task lists, blockquotes
- Links, images, horizontal rules
- No runtime dependencies -- built with Swift and Command Line Tools (no Xcode required)

## Requirements

- macOS 12+
- Swift (via Xcode Command Line Tools)

## Installation

```bash
git clone https://github.com/YendiGB/QLMarkdownViewer.git
cd QLMarkdownViewer
make install
```

After installation:
1. Open the app once from `~/Applications/QLMarkdownViewer.app`
2. The Quick Look extension registers automatically
3. Select any `.md` or `.markdown` file in Finder and press Space

If the extension doesn't activate, enable it in:
System Settings > General > Login Items & Extensions > Quick Look

## Uninstall

```bash
make uninstall
```

## Build Only

```bash
make build
```

The built app will be at `build/QLMarkdownViewer.app`.

## Architecture

This is a macOS Quick Look Preview Extension (.appex) embedded in a minimal host app:

- **Host app** -- minimal macOS app that exists only to deliver the extension
- **Preview extension** -- data-based Quick Look extension that converts Markdown to HTML
- **MarkdownParser** -- regex-based GFM Markdown-to-HTML converter
- **CSS** -- GitHub-flavored stylesheet with automatic light/dark mode

## License

MIT
