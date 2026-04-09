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
