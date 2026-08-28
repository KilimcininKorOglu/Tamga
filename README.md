# Tamga

A native macOS text editor with tree-sitter syntax highlighting and tab support, designed as a lightweight alternative to Notepad++.

Built with SwiftUI and AppKit. Requires macOS 13.0 (Ventura) or later.

## Features

### Core Editing

- **Tab System** - Open multiple files in tabs with drag-and-drop reordering
- **Syntax Highlighting** - 13 languages, with tree-sitter handling embedded multi-language files (JavaScript and CSS inside HTML, or PHP + HTML + JS + CSS in a single file)
- **Session Restore** - Saves and restores all open tabs, including unsaved untitled ones
- **Find & Replace** - Case-insensitive search with match navigation, replace and replace all
- **Go to Line** - Quick navigation to a specific line number
- **File Comparison** - Side-by-side diff view
- **Encoding Support** - UTF-8, UTF-16, ASCII and ISO-8859-1, with BOM-aware detection on open

### Editor Features

- Line numbers
- Word wrap toggle
- Invisible characters display
- Code folding (fold, unfold, fold all, unfold all)
- Duplicate line
- Move line up and down
- Sort lines (ascending and descending)
- Remove duplicate lines
- Change case (uppercase, lowercase, capitalize)
- JSON formatting and minification
- Auto-indent and 4-space tab insertion
- Split view

### Interface

- Native macOS design
- Light, Dark and System theme support
- Customizable font and size
- Status bar with line, column and character count
- Sidebar with open tabs and recent files
- Markdown preview
- Drag and drop file opening
- Recent files menu
- Auto-save option
- Print support

### Localization

Available in 20 languages: Arabic, Bengali, Chinese (Simplified), Dutch, English, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese, Russian, Spanish, Thai, Turkish, Ukrainian, Vietnamese.

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac
- Xcode 15 or later to build from source

## Installation

### Download

Download the latest release from the [Releases](../../releases) page.

### Build from Source

The Xcode project lives in the `Tamga/` subdirectory, so `-project` is required when building from the repository root.

```bash
# Clone the repository
git clone https://github.com/KilimcininKorOglu/Tamga.git
cd Tamga

# Build
xcodebuild -project Tamga/Tamga.xcodeproj -scheme Tamga -destination 'platform=macOS' build

# Or open in Xcode
open Tamga/Tamga.xcodeproj
```

Package dependencies (SwiftTreeSitter, Neon, Rearrange, tree-sitter) resolve automatically through Swift Package Manager. The tree-sitter grammars themselves are vendored in `Tamga/Vendor/TamgaGrammars` and need no extra setup.

## CLI Usage

Install the CLI tool from **Help > Install CLI Tool** in the app menu. It writes a launcher script to `/usr/local/bin/tamga`.

```bash
# Open a file
tamga file.txt

# Open multiple files
tamga file1.txt file2.py file3.json

# Launch the app
tamga
```

## Supported Syntax Languages

| Language   | Extensions                   | Engine      |
|------------|------------------------------|-------------|
| Plain Text | .txt, .text                  | Pattern     |
| Swift      | .swift                       | Tree-sitter |
| Python     | .py, .pyw                    | Tree-sitter |
| JavaScript | .js, .jsx, .ts, .tsx         | Tree-sitter |
| PHP        | .php, .phtml, .php3-5, .phps | Tree-sitter |
| JSON       | .json                        | Tree-sitter |
| HTML       | .html, .htm                  | Tree-sitter |
| CSS        | .css, .scss, .sass, .less    | Tree-sitter |
| Markdown   | .md, .markdown               | Pattern     |
| XML        | .xml, .plist                 | Tree-sitter |
| SQL        | .sql                         | Tree-sitter |
| Shell      | .sh, .bash, .zsh             | Tree-sitter |
| YAML       | .yml, .yaml                  | Tree-sitter |

Tree-sitter parsing also enables embedded multi-language highlighting: a single file can color several languages at once, such as `<script>` JavaScript and `<style>` CSS inside an HTML file, or PHP, HTML, JavaScript and CSS together in a `.php` file. Markdown and plain text use a built-in pattern highlighter.

The language is detected from the file extension on open and on save. An untitled or extensionless tab stays Plain Text until it is saved, and any tab's language can be set by hand from the status bar picker.

## Keyboard Shortcuts

### File Operations

| Shortcut           | Action         |
|--------------------|----------------|
| Cmd+N              | New Tab        |
| Cmd+O              | Open File      |
| Cmd+S              | Save           |
| Cmd+Shift+S        | Save As        |
| Cmd+W              | Close Tab      |
| Cmd+Shift+Option+W | Close All Tabs |
| Cmd+P              | Print          |

### Edit Operations

| Shortcut     | Action              |
|--------------|---------------------|
| Cmd+F        | Find                |
| Cmd+G        | Find Next           |
| Cmd+Shift+G  | Find Previous       |
| Cmd+Option+F | Replace             |
| Cmd+L        | Go to Line          |
| Cmd+D        | Duplicate Line      |
| Option+Up    | Move Line Up        |
| Option+Down  | Move Line Down      |
| Cmd+Shift+U  | Uppercase Selection |
| Cmd+Shift+L  | Lowercase Selection |
| Cmd+Shift+J  | Format JSON         |

Sort Lines, Remove Duplicate Lines, Capitalize and Minify JSON have no shortcut and are available from the Edit menu.

### Code Folding

| Shortcut               | Action     |
|------------------------|------------|
| Cmd+Option+Left        | Fold       |
| Cmd+Option+Right       | Unfold     |
| Cmd+Option+Shift+Left  | Fold All   |
| Cmd+Option+Shift+Right | Unfold All |

### View

| Shortcut     | Action            |
|--------------|-------------------|
| Cmd+B        | Toggle Sidebar    |
| Cmd+Option+W | Toggle Word Wrap  |
| Cmd+\        | Toggle Split View |
| Cmd+Shift+M  | Markdown Preview  |
| Cmd+Option+8 | Show Invisibles   |
| Cmd++        | Zoom In           |
| Cmd+-        | Zoom Out          |
| Cmd+0        | Reset Zoom        |

Line Numbers and Status Bar toggles, plus the Theme and Language pickers, sit in the View menu without shortcuts.

### Tab Navigation

| Shortcut        | Action       |
|-----------------|--------------|
| Cmd+Shift+Right | Next Tab     |
| Cmd+Shift+Left  | Previous Tab |
| Cmd+1-9         | Switch Tab   |

## Project Structure

```
Tamga/
├── Tamga.xcodeproj/
├── Vendor/TamgaGrammars/       # Local SwiftPM package: vendored tree-sitter grammars
└── Tamga/
    ├── TamgaApp.swift          # App entry point, CLI arguments, AppDelegate
    ├── TamgaCommands.swift     # Menu bar commands
    ├── Models/                 # Tab, DocumentInfo, AppState
    ├── Views/                  # Editor, tab bar, gutter, status bar, panels
    ├── ViewModels/             # TabManager, DocumentViewModel
    ├── Services/               # File I/O, session, highlighting, print, CLI installer
    ├── Localization/           # 20 .lproj directories
    └── Utilities/              # Constants and extensions
```

Release notes live in [CHANGELOG.md](CHANGELOG.md). Mac App Store submission notes live under `docs/`.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -m 'feat: add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Open a Pull Request

### Development Guidelines

- Use camelCase for all identifiers
- Wrap every user-facing string in `String(localized: "key")` and add the key to all 20 language files
- Write commit messages as `type: description` in English, using the conventional prefixes `feat`, `fix`, `docs` and `refactor`
- Follow `.swiftlint.yml` and `.swift-format` at the repository root; no function may exceed a cyclomatic complexity of 10
- Ensure the build succeeds before committing
- Test on both Light and Dark modes

## License

Released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with SwiftUI and AppKit
- Syntax highlighting powered by tree-sitter through SwiftTreeSitter and Neon
- Inspired by Notepad++ and CotEditor
