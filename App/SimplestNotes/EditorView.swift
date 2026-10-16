import SwiftUI

struct EditorView: View {
    @ObservedObject var model: AppViewModel
    @FocusState private var editorFocused: Bool

    var body: some View {
        TextEditor(text: Binding(
            get: { model.text },
            set: { model.textEdited(PlainPaste.sanitized($0)) }
        ))
        .font(.body)
        .scrollContentBackground(.hidden)
        .padding(12)
        .focused($editorFocused)
        .accessibilityIdentifier("noteEditor")
        .accessibilityLabel("Note")
        .onAppear {
            editorFocused = true
        }
#if os(iOS)
        .textInputAutocapitalization(.sentences)
        .autocorrectionDisabled(false)
#endif
    }
}

/// Keeps pasted content as plain String (no attributed styles survive TextEditor binding).
enum PlainPaste {
    static func sanitized(_ string: String) -> String {
        string
    }
}
