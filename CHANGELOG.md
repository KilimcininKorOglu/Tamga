# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.0] - 2026-09-20

### Added
- Symbol outline panel in the sidebar
- URL detection with underlines and Cmd-click open
- Word-based autocomplete built from the document's own words
- Bracket matching and auto-close pairs
- Highlight all occurrences of the selected word
- Indent guides with a View menu toggle
- Trim Trailing Whitespace transform
- Document minimap with a viewport indicator and click-to-scroll
- Fuzzy command palette
- Editor font selection through the system font panel
- Document export to HTML and PDF
- Markdown highlighting with tree-sitter
- Dockerfile syntax highlighting
- Go, Rust, C, Java, and C++ syntax highlighting
- Preferences window
- Reopen closed tabs, plus more working encodings
- Reload for files changed on disk
- Line-ending detection and conversion
- Regex, case-sensitive, and whole-word find
- Find match selection and highlighting in the editor
- TOML and INI-style config file highlighting
- Remove Empty Lines edit command
- More file extensions recognized per language
- Save action in the unsaved-changes close alert
- Replace command in the Edit menu

### Changed
- Daily workflow that deletes leftover GitHub Actions artifacts
- Unit test target for the core logic
- Dead code removed across services, view models, and utilities
- Unused constants and the duplicate version literal dropped
- Menu commands and their services extracted from TamgaApp
- Text view moved out of EditorView into its own files
- Repeated observer registrations replaced with a lookup table
- CLI installer split into smaller units
- Markdown preview stylesheet extracted
- Mapping switches replaced with lookup tables
- SwiftLint and swift-format configuration added, and the sources formatted
- Readme corrected and expanded, clone URL pointed at the renamed repository
- MIT license file added
- Code coverage profraw files ignored

### Fixed
- Only the active file is watched, which avoids permission prompts at launch
- Find panel made compact and centered
- Stray file creation stopped, and a symlinked install target refused
- Relaunch works without a force-unwrap or a deprecated launch API
- Caret offsets and invisible characters computed in UTF-16 units
- SQL keywords matched case-insensitively in the regex highlighter
- CLI install failures reported instead of a false success
- Whole JSON document replaced by UTF-16 length
- Terminal session saves serialized with background saves
- Autosave timer starts when Auto Save is toggled on
- Edit menu transformations made undoable
- Files written with the tab's selected encoding
- Paths escaped before they reach the privileged install command
- Untitled tab counter restored with the session
- Corrupt session file quarantined instead of overwritten
- Session persisted on focus loss regardless of Auto Save
- Save failures reported for both the new-path and existing-path saves
- Undecodable files warn instead of opening blank
- Undo preserved when the regex highlighter runs
- Line numbers aligned with the real and wrapped text layout
- Editor and tab bar no longer render blank
- Tab bar stays below the title bar on the current SDK
- Real cursor position reported in the status bar
- Language icon table used for recent-file rows
- Replace All no longer loops forever
- Remaining Turkish comment translated to English

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
