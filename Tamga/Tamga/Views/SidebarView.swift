import SwiftUI

/// Sidebar showing recent files and open tabs
struct SidebarView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var appState = AppState.shared
    let onOpenFile: (URL) -> Void

    @State private var selectedSection: SidebarSection = .openTabs

    private enum SidebarSection: String, CaseIterable {
        case openTabs = "open.tabs"
        case recentFiles = "recent.files"
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
        .xml: "doc.richtext"
    ]

    private func fileIcon(for language: SyntaxLanguage) -> String {
        Self.languageIcons[language] ?? "doc.text"
    }

    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift":
            return "swift"
        case "py":
            return "text.word.spacing"
        case "js", "ts":
            return "curlybraces"
        case "json":
            return "curlybraces.square"
        case "html", "htm":
            return "chevron.left.forwardslash.chevron.right"
        case "css":
            return "paintbrush"
        case "md", "markdown":
            return "text.justify"
        default:
            return "doc.text"
        }
    }
}
