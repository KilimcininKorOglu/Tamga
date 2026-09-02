import SwiftUI

/// Find and Replace panel view
struct FindReplaceView: View {
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var isVisible: Bool
    @Binding var showReplace: Bool
    @Binding var isRegexEnabled: Bool
    @Binding var isCaseSensitive: Bool
    @Binding var isWholeWord: Bool
    let matchCount: Int
    let currentMatch: Int
    let isSearchInvalid: Bool
    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    let onReplace: () -> Void
    let onReplaceAll: () -> Void

    @FocusState private var isSearchFocused: Bool

    /// Counter text: an invalid-regex notice, the match position, or a no-results notice.
    private var counterLabel: String {
        if isSearchInvalid { return String(localized: "invalid.regex") }
        if matchCount > 0 { return "\(currentMatch + 1)/\(matchCount)" }
        return String(localized: "no.results")
    }

    private var counterColor: Color {
        (isSearchInvalid || matchCount == 0) ? .red : .secondary
    }

    /// A small toggle button for a search option (case, whole word, regex). Tints its
    /// background when active, so the enabled options read at a glance.
    private func optionToggle(symbol: String, isOn: Binding<Bool>, help: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: symbol)
                .frame(width: 20, height: 18)
                .background(isOn.wrappedValue ? Color.accentColor.opacity(0.3) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.borderless)
        .help(String(localized: String.LocalizationValue(help)))
    }

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

                // Search option toggles: case, whole word, regex.
                optionToggle(symbol: "textformat", isOn: $isCaseSensitive, help: "case.sensitive")
                optionToggle(symbol: "textformat.abc", isOn: $isWholeWord, help: "whole.word")
                optionToggle(symbol: "asterisk", isOn: $isRegexEnabled, help: "regex")

                // Match counter next to the field, so the count stays beside the query
                // instead of being pushed to the far window edge.
                if !searchText.isEmpty {
                    Text(counterLabel)
                        .font(.caption)
                        .foregroundColor(counterColor)
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
            isRegexEnabled: .constant(false),
            isCaseSensitive: .constant(false),
            isWholeWord: .constant(false),
            matchCount: 5,
            currentMatch: 2,
            isSearchInvalid: false,
            onFindNext: {},
            onFindPrevious: {},
            onReplace: {},
            onReplaceAll: {}
        )
        Spacer()
    }
    .frame(width: 500, height: 200)
}
