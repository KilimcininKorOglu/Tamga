import SwiftUI

/// A single action the command palette can run.
struct PaletteCommand: Identifiable {
    let id = UUID()
    let title: String
    let run: () -> Void
}

/// A fuzzy command palette overlay. Type to filter by subsequence, Enter runs the top
/// result, Esc closes. Modeled on the find panel's overlay placement.
struct CommandPaletteView: View {
    @Binding var isVisible: Bool
    let commands: [PaletteCommand]

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    private var filtered: [PaletteCommand] {
        guard !query.isEmpty else { return commands }
        return commands.filter { Self.fuzzyMatch(query, in: $0.title) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "command")
                    .foregroundColor(.secondary)
                TextField(String(localized: "command.palette.placeholder"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit(runSelected)
                    .onChange(of: query) { _ in selectedIndex = 0 }
            }
            .padding(12)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, command in
                        Button {
                            run(command)
                        } label: {
                            Text(command.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(index == selectedIndex ? Color.accentColor.opacity(0.25) : Color.clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .frame(width: 520)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .onAppear { isFocused = true }
        .onExitCommand { isVisible = false }
        .onMoveCommand { direction in
            move(direction)
        }
    }

    private func move(_ direction: MoveCommandDirection) {
        guard !filtered.isEmpty else { return }
        if direction == .down {
            selectedIndex = min(selectedIndex + 1, filtered.count - 1)
        } else if direction == .up {
            selectedIndex = max(selectedIndex - 1, 0)
        }
    }

    private func runSelected() {
        guard filtered.indices.contains(selectedIndex) else { return }
        run(filtered[selectedIndex])
    }

    private func run(_ command: PaletteCommand) {
        isVisible = false
        command.run()
    }

    /// Case-insensitive subsequence match: every character of `query` appears in `title`
    /// in order, so `wc` matches "Word Count".
    private static func fuzzyMatch(_ query: String, in title: String) -> Bool {
        let lowerTitle = title.lowercased()
        var cursor = lowerTitle.startIndex
        for character in query.lowercased() {
            guard let found = lowerTitle[cursor...].firstIndex(of: character) else { return false }
            cursor = lowerTitle.index(after: found)
        }
        return true
    }
}
