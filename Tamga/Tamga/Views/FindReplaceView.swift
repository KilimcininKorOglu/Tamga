import SwiftUI

/// Find and Replace panel view
struct FindReplaceView: View {
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var isVisible: Bool
    @Binding var showReplace: Bool
    let matchCount: Int
    let currentMatch: Int
    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    let onReplace: () -> Void
    let onReplaceAll: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Search row
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                TextField(String(localized: "find.placeholder"), text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 220)
                    .focused($isSearchFocused)
                    .onSubmit {
                        onFindNext()
                    }

                // Match counter next to the field, so the count stays beside the query
                // instead of being pushed to the far window edge.
                if !searchText.isEmpty {
                    Text(matchCount > 0 ? "\(currentMatch + 1)/\(matchCount)" : String(localized: "no.results"))
                        .font(.caption)
                        .foregroundColor(matchCount > 0 ? .secondary : .red)
                        .frame(minWidth: 44, alignment: .trailing)
                        .monospacedDigit()
                }

                Button(action: onFindPrevious) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(matchCount == 0)
                .help(String(localized: "find.previous"))

                Button(action: onFindNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(matchCount == 0)
                .help(String(localized: "find.next"))

                Divider()
                    .frame(height: 16)

                Button(action: { showReplace.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: showReplace ? "chevron.up.square" : "chevron.down.square")
                        Text(String(localized: "replace"))
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderless)
                .help(String(localized: "toggle.replace"))

                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "close"))
            }

            // Replace row
            if showReplace {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.swap")
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    TextField(String(localized: "replace.placeholder"), text: $replaceText)
                        .textFieldStyle(.plain)
                        .frame(width: 220)
                        .onSubmit {
                            onReplace()
                        }

                    Button(String(localized: "replace")) {
                        onReplace()
                    }
                    .buttonStyle(.borderless)
                    .disabled(matchCount == 0)

                    Button(String(localized: "replace.all")) {
                        onReplaceAll()
                    }
                    .buttonStyle(.borderless)
                    .disabled(matchCount == 0)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onAppear {
            isSearchFocused = true
        }
    }
}

#Preview {
    VStack {
        FindReplaceView(
            searchText: .constant("test"),
            replaceText: .constant(""),
            isVisible: .constant(true),
            showReplace: .constant(true),
            matchCount: 5,
            currentMatch: 2,
            onFindNext: {},
            onFindPrevious: {},
            onReplace: {},
            onReplaceAll: {}
        )
        Spacer()
    }
    .frame(width: 500, height: 200)
}
