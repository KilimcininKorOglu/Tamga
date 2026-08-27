# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-08-27

### Added
- Initial Tamga macOS notepad application
- Tree-sitter based syntax highlighting, including embedded languages in PHP and HTML files
- PHP syntax highlighting support
- Find and Replace panel (Cmd+F)
- Go to Line panel (Cmd+L)
- Duplicate Line (Cmd+D) and Move Line (Option+Up/Down)
- Auto-indent on the Enter key
- Text utilities: Sort Lines, Remove Duplicates, Change Case
- JSON formatter (format and minify)
- Auto-save
- Print support (Cmd+P)
- Drag and drop file support
- Code folding
- Split view (Cmd+\)
- File sidebar (Cmd+B)
- Markdown preview (Cmd+Shift+M)
- Whitespace visualization
- Encoding change
- Compare Files
- In-app language switching, with an automatic restart on change
- Support for 18 additional interface languages
- CLI support for opening files from the terminal
- Automatic session save that protects unsaved tabs against abrupt termination
- Red dirty indicator and an unsaved-tab warning when closing
- App icon built from the letter T
- App icon and author credit in the about panel
- Enhanced dark mode support

### Changed
- Localization moved to separate .strings files

### Fixed
- Code folding rewritten as layout-based, which stops it from corrupting document content
- Tab bar scrolls with the mouse wheel
- Save panel proposes the tab name instead of a generic file name
- Both the app menu and the Help menu open the same about panel
- CLI files open after the session is restored
- Untitled counter resets when the last tab closes
- File icon turns red while a tab is dirty
- Keyboard shortcuts no longer use Turkish characters
- Grammar errors in the Turkish translations
- App Store transliterations converted to native characters
