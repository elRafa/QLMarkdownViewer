# QLMarkdownViewer -- Design Spec

**Date:** 2026-04-09
**Status:** Approved

## Overview

A native macOS Quick Look generator plugin (`.qlgenerator`) that renders Markdown files as styled HTML when pressing Space in Finder. Built with Swift, no Xcode required.

## Goals

- Render `.md` and `.markdown` files in Finder Quick Look
- GitHub-flavored Markdown rendering (GFM)
- Automatic light/dark mode matching macOS system appearance
- Zero runtime dependencies -- single compiled binary
- Simple install via Makefile

## Non-Goals

- Full CommonMark spec compliance (regex-based parser covers ~90% of GFM)
- Live-reload or editing capability
- Rendering images with relative paths (Quick Look sandboxing prevents this)
- Modern Quick Look Preview Extension (requires Xcode, which is not installed)

## Architecture

### Plugin Type

A `.qlgenerator` bundle using the legacy Quick Look Generator API. This API is still functional on macOS 26 and does not require Xcode to build -- only `swiftc` from Command Line Tools.

### Processing Pipeline

1. Finder triggers Quick Look for a file with UTI `net.daringfireball.markdown`
2. The plugin's `GeneratePreviewForURL` function is called
3. Plugin reads the raw Markdown file contents as UTF-8
4. A regex-based Markdown-to-HTML converter processes the content, handling:
   - Headings (h1-h6 via `#` syntax)
   - Bold, italic, strikethrough, inline code
   - Fenced code blocks (with language class for CSS highlighting)
   - Unordered and ordered lists
   - Task lists (`- [ ]` / `- [x]`)
   - Tables (GFM pipe syntax)
   - Blockquotes
   - Links and images
   - Horizontal rules
   - Paragraphs and line breaks
5. The HTML is wrapped in a template with embedded CSS
6. The styled HTML is returned to Quick Look for rendering via WebView

### File Structure

```
QLMarkdownViewer/
  src/
    GeneratePreviewForURL.swift   -- preview generation + Markdown parser
    GenerateThumbnailForURL.swift  -- thumbnail generation (returns empty/stub)
    main.c                         -- C entry point required by QL generator API
  resources/
    Info.plist                     -- bundle config, UTI declarations
    style.css                      -- GitHub-flavored light/dark mode CSS
  Makefile                         -- build, install, uninstall, clean targets
  README.md                        -- usage instructions
  LICENSE                          -- MIT license
```

### Key Implementation Details

**Plugin entry point:** The Quick Look Generator API requires a C-based plugin architecture using `CFPlugin` / `CFBundle`. The `main.c` file registers the plugin factory function. The factory returns a vtable with `GeneratePreviewForURL` and `GenerateThumbnailForURL` callbacks implemented in Swift.

**Markdown parser:** A self-contained regex-based converter in Swift. No external dependencies (no cmark, no swift-markdown SPM package). Processes the file line-by-line and block-by-block:
- Block-level pass: identifies code fences, headings, blockquotes, lists, tables, horizontal rules, paragraphs
- Inline pass: processes bold, italic, strikethrough, code, links, images within each block

**CSS styling:**
- Uses `@media (prefers-color-scheme: dark)` for automatic theme switching
- Light mode: `#ffffff` background, `#1f2328` text, `#d1d9e0` borders
- Dark mode: `#0d1117` background, `#e6edf3` text, `#3d444d` borders
- Font stack: `-apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif`
- Code font: `ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace`
- Max content width: 980px, centered
- Table styling, task list checkboxes, blockquote left border

**Thumbnail generation:** Returns an empty/no-op result. Quick Look will fall back to the default file icon for thumbnails.

## Supported UTIs and Extensions

| Extension    | UTI                              |
|-------------|----------------------------------|
| `.md`       | `net.daringfireball.markdown`    |
| `.markdown` | `net.daringfireball.markdown`    |

The plugin also declares `public.text` and `public.data` as conforming types in Info.plist to ensure broad matching.

## Build System

The `Makefile` provides:

- `make build` -- compiles Swift sources with `swiftc`, bundles into `.qlgenerator` with correct directory structure and Info.plist
- `make install` -- copies the `.qlgenerator` bundle to `~/Library/QuickLook/` and runs `qlmanage -r` to reload
- `make uninstall` -- removes the bundle from `~/Library/QuickLook/` and reloads
- `make clean` -- removes build artifacts

### Build Details

The build step:
1. Compiles Swift files into a dynamic library (`.dylib`)
2. Compiles `main.c` and links with the Swift dylib
3. Assembles the `.qlgenerator` bundle structure:
   ```
   QLMarkdownViewer.qlgenerator/
     Contents/
       Info.plist
       MacOS/
         QLMarkdownViewer    -- compiled binary
       Resources/
         style.css
   ```

## Installation

```bash
git clone https://github.com/YendiGB/QLMarkdownViewer.git
cd QLMarkdownViewer
make build
make install
```

After installation, press Space on any `.md` or `.markdown` file in Finder to see the rendered preview.

## Testing Plan

1. Build the plugin with `make build` -- verify no compilation errors
2. Install with `make install` -- verify bundle appears in `~/Library/QuickLook/`
3. Run `qlmanage -r` -- verify no errors
4. Test with `qlmanage -p test.md` -- verify HTML preview renders
5. Create test Markdown files covering: headings, code blocks, tables, task lists, bold/italic, links, blockquotes
6. Verify light/dark mode switching by toggling macOS appearance
7. Test both `.md` and `.markdown` extensions
8. Test uninstall with `make uninstall`

## GitHub Repository

- Name: `QLMarkdownViewer`
- Owner: `YendiGB`
- Visibility: public (open-source utility)
- License: MIT
