import SwiftUI

/// Go to Line panel view
struct GoToLineView: View {
    @Binding var isVisible: Bool
    @State private var lineNumberText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    let totalLines: Int
    let onGoToLine: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(localized: "go.to.line"))
                    .font(.headline)
                Spacer()
                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 8) {
                TextField(String(localized: "line.number"), text: $lineNumberText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        goToLine()
                    }

                Text("/ \(totalLines)")
                    .foregroundColor(.secondary)
                    .frame(minWidth: 60, alignment: .leading)
            }

            HStack {
                Spacer()
                Button(String(localized: "cancel")) {
                    isVisible = false
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button(String(localized: "go")) {
                    goToLine()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!isValidLineNumber)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .onAppear {
            isTextFieldFocused = true
            lineNumberText = ""
        }
    }

    private var isValidLineNumber: Bool {
        guard let lineNumber = Int(lineNumberText) else { return false }
        return lineNumber >= 1 && lineNumber <= totalLines
    }

    private func goToLine() {
        guard let lineNumber = Int(lineNumberText),
            lineNumber >= 1 && lineNumber <= totalLines
        else { return }
        onGoToLine(lineNumber)
        isVisible = false
    }
}

#Preview {
    GoToLineView(
        isVisible: .constant(true),
        totalLines: 100,
        onGoToLine: { line in print("Go to line \(line)") }
    )
    .frame(width: 400, height: 200)
}
