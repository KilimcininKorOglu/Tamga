import SwiftUI

/// Sidebar showing recent files and open tabs
struct SidebarView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var appState = AppState.shared
    let onOpenFile: (URL) -> Void
    let onGoToLine: (Int) -> Void

    @State private var selectedSection: SidebarSection = .openTabs

    private enum SidebarSection: String, CaseIterable {
        case openTabs = "open.tabs"
        case recentFiles = "recent.files"
        case outline = "outline"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section Picker
            Picker("", selection: $selectedSection) {
                ForEach(SidebarSection.allCases, id: \.self) { section in
                    Text(String(localized: String.LocalizationValue(section.rawValue)))
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            // Content
            switch selectedSection {
            case .openTabs:
                openTabsSection
            case .recentFiles:
                recentFilesSection
            case .outline:
                outlineSection
            }

            Spacer()
        }
        .frame(minWidth: 200, maxWidth: 300)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Open Tabs Section

    private var openTabsSection: some View {
        List(tabManager.tabs) { tab in
            HStack {
                Image(systemName: fileIcon(for: tab.language))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(tab.title)
                            .fontWeight(tabManager.activeTabId == tab.id ? .semibold : .regular)

                        if tab.isDirty {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                        }
                    }

                    if let path = tab.filePath {
                        Text(path.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                tabManager.activeTabId = tab.id
            }
            .listRowBackground(
                tabManager.activeTabId == tab.id
                    ? Color.accentColor.opacity(0.2)
                    : Color.clear
            )
        }
        .listStyle(.plain)
    }

    // MARK: - Recent Files Section

    private var recentFilesSection: some View {
        Group {
            if appState.recentFiles.isEmpty {
                VStack {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(String(localized: "no.recent.files"))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.recentFiles, id: \.self) { url in
                    HStack {
                        Image(systemName: fileIcon(for: url))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                            Text(url.deletingLastPathComponent().path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onOpenFile(url)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Outline Section

    private var outlineSymbols: [DocumentSymbol] {
        guard let tab = tabManager.activeTab else { return [] }
        return SymbolExtractor.symbols(in: tab.content, language: tab.language)
    }

    private var outlineSection: some View {
        Group {
            let symbols = outlineSymbols
            if symbols.isEmpty {
                VStack {
                    Image(systemName: "list.bullet.indent")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(String(localized: "no.symbols"))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(symbols) { symbol in
                    HStack {
                        Image(systemName: symbol.kind.icon)
                            .foregroundColor(.secondary)
                            .frame(width: 16)

                        Text(symbol.name)
                            .lineLimit(1)

                        Spacer()

                        Text("\(symbol.line)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onGoToLine(symbol.line)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    /// SF Symbol shown next to a tab, per language. Add an entry here when adding a
    /// `SyntaxLanguage` case.
    private static let languageIcons: [SyntaxLanguage: String] = [
        .swift: "swift",
        .python: "text.word.spacing",
        .javascript: "curlybraces",
        .json: "curlybraces.square",
        .html: "chevron.left.forwardslash.chevron.right",
        .css: "paintbrush",
        .markdown: "text.justify",
        .plainText: "doc.text",
        .php: "p.square",
        .sql: "cylinder",
        .shell: "terminal",
        .yaml: "list.bullet.indent",
        .xml: "doc.richtext",
        .toml: "gearshape",
        .go: "g.square",
        .rust: "r.square",
        .c: "c.square",
        .java: "cup.and.saucer",
        .cpp: "plus.square",
        .dockerfile: "shippingbox"
    ]

    private func fileIcon(for language: SyntaxLanguage) -> String {
        Self.languageIcons[language] ?? "doc.text"
    }

    private func fileIcon(for url: URL) -> String {
        // Derive the icon from the detected language so recent-file rows use the same
        // table as open tabs, covering php, sql, shell, yaml, and xml too.
        fileIcon(for: SyntaxLanguage.detect(from: url))
    }
}
