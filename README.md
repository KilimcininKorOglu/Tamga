# Tamga

A native macOS text editor with syntax highlighting and tab support, designed as a lightweight alternative to Notepad++.

## Features

### Core Editing
- **Tab System** - Open multiple files in tabs with drag-and-drop reordering
- **Syntax Highlighting** - Highlighting for 13 languages, with tree-sitter powering embedded multi-language files (JavaScript and CSS inside HTML, or PHP + HTML + JS + CSS in a single file)
- **Session Restore** - Automatically saves and restores all open tabs
- **Find & Replace** - Search with regex support
- **Go to Line** - Quick navigation to specific line numbers
- **File Comparison** - Side-by-side diff view

### Editor Features

- Line numbers
- Word wrap toggle
- Invisible characters display
- Code folding (fold/unfold)
- Duplicate line
- Move line up/down
- Sort lines (ascending/descending)
- Remove duplicate lines
- Change case (uppercase/lowercase/capitalize)
- JSON formatting and minification
- Split view

### Interface

- Native macOS design
- Light/Dark/System theme support
- Customizable font and size
- Status bar with line/column/character count
- Sidebar with open tabs list
- Markdown preview
- Drag and drop file opening
- Recent files menu
- Auto-save option
- Print support

### Localization
Available in 20 languages:
Arabic, Bengali, Chinese (Simplified), Dutch, English, French, German, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese, Russian, Spanish, Thai, Turkish, Ukrainian, Vietnamese

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Installation

### Download
Download the latest release from the [Releases](../../releases) page.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/KilimcininKorOglu/Tamga.git
cd Tamga

# Build (the Xcode project lives in the Tamga/ subdirectory)
xcodebuild -project Tamga/Tamga.xcodeproj -scheme Tamga -destination 'platform=macOS' build

# Or open in Xcode
open Tamga/Tamga.xcodeproj
```

## CLI Usage

Install the CLI tool from **Help > Install CLI Tool...** in the app menu.

```bash
# Open a file
tamga file.txt

# Open multiple files
tamga file1.txt file2.py file3.json

# Launch the app
tamga
```

## Supported Syntax Languages

| Language   | Extensions                   |
|------------|------------------------------|
| Plain Text | .txt, .text                  |
| Swift      | .swift                       |
| Python     | .py, .pyw                    |
| JavaScript | .js, .jsx, .ts, .tsx         |
| PHP        | .php, .phtml, .php3-5, .phps |
| JSON       | .json                        |
| HTML       | .html, .htm                  |
| CSS        | .css, .scss, .sass, .less    |
| Markdown   | .md, .markdown               |
| XML        | .xml, .plist                 |
| SQL        | .sql                         |
| Shell      | .sh, .bash, .zsh             |
| YAML       | .yml, .yaml                  |

Most languages are highlighted by a tree-sitter parser, which also enables embedded multi-language highlighting: a single file can color several languages at once, such as `<script>` JavaScript and `<style>` CSS inside an HTML file, or PHP, HTML, JavaScript, and CSS together in a `.php` file. Markdown and plain text use a built-in pattern highlighter.

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

| Shortcut    | Action              |
|-------------|---------------------|
| Cmd+F       | Find                |
| Cmd+G       | Find Next           |
| Cmd+Shift+G | Find Previous       |
| Cmd+L       | Go to Line          |
| Cmd+D       | Duplicate Line      |
| Option+Up   | Move Line Up        |
| Option+Down | Move Line Down      |
| Cmd+Shift+U | Uppercase Selection |
| Cmd+Shift+L | Lowercase Selection |
| Cmd+Shift+J | Format JSON         |

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
└── Tamga/
    ├── TamgaApp.swift
    ├── Models/
    ├── Views/
    ├── ViewModels/
    ├── Services/
    ├── Localization/
    └── Utilities/
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -m 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Open a Pull Request

### Development Guidelines

- Use camelCase for all identifiers
- Add localization strings to all 20 language files
- Ensure build succeeds before committing
- Test on both Light and Dark modes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI and AppKit
- Syntax highlighting powered by tree-sitter via SwiftTreeSitter and Neon
- Inspired by Notepad++ and CotEditor
