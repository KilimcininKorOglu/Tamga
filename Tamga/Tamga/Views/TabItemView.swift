import SwiftUI

/// Individual tab item view
struct TabItemView: View {
    let tab: Tab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false
    @State private var showCloseAlert = false
    @Environment(\.colorScheme) private var colorScheme

    private var hoverColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.gray.opacity(0.1)
    }

    private var selectedColor: Color {
        colorScheme == .dark
            ? Color.accentColor.opacity(0.25)
            : Color.accentColor.opacity(0.15)
    }

    var body: some View {
        HStack(spacing: 6) {
            // File icon
            Image(systemName: tab.filePath != nil ? "doc.text.fill" : "doc.text")
                .font(.system(size: 12))
                .foregroundColor(tab.isDirty ? .red : (isSelected ? .accentColor : .secondary))

            // Title
            Text(displayTitle)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(isSelected ? .primary : .secondary)

            // Close button
            if isHovering || isSelected {
                Button(action: handleClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
            } else {
                Spacer()
                    .frame(width: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? selectedColor : (isHovering ? hoverColor : Color.clear))
        )
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
        .alert(String(localized: "unsaved.changes"), isPresented: $showCloseAlert) {
            Button(String(localized: "save")) {
                NotificationCenter.default.post(name: .saveAndCloseTab, object: tab.id)
            }
            Button(String(localized: "dont.save"), role: .destructive) {
                onClose()
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "unsaved.changes.message"))
        }
        .contextMenu {
            Button(String(localized: "close.tab")) {
                handleClose()
            }

            Button(String(localized: "close.other.tabs")) {
                NotificationCenter.default.post(
                    name: .closeOtherTabs,
                    object: tab.id
                )
            }

            Divider()

            if let path = tab.filePath {
                Button(String(localized: "show.in.finder")) {
                    NSWorkspace.shared.selectFile(path.path, inFileViewerRootedAtPath: "")
                }

                Button(String(localized: "copy.path")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path.path, forType: .string)
                }
            }
        }
    }

    private var displayTitle: String {
        if tab.isDirty {
            return tab.title + " *"
        }
        return tab.title
    }

    private func handleClose() {
        if tab.isDirty {
            showCloseAlert = true
        } else {
            onClose()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let closeOtherTabs = Notification.Name("closeOtherTabs")
    static let saveAndCloseTab = Notification.Name("saveAndCloseTab")
}

#Preview {
    HStack {
        TabItemView(
            tab: Tab(title: "untitled.swift", isDirty: true),
            isSelected: true,
            onSelect: {},
            onClose: {}
        )

        TabItemView(
            tab: Tab(title: "main.swift", isDirty: false),
            isSelected: false,
            onSelect: {},
            onClose: {}
        )
    }
    .padding()
}
