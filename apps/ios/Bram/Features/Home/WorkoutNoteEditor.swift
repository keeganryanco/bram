import SwiftUI

struct WorkoutNoteEditor: View {
    @Binding var noteBody: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $noteBody)
            .focused($isFocused)
            .scrollContentBackground(.hidden)
            .font(BramFont.body(size: 20))
            .foregroundStyle(BramColor.textPrimary)
            .tint(BramColor.violet)
            .frame(minHeight: 270, alignment: .topLeading)
            .overlay(alignment: .topLeading) {
                if noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Write what you did. Bram will sort it out.")
                        .font(BramFont.body(size: 20))
                        .foregroundStyle(BramColor.textTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 20)
            .accessibilityLabel("Workout note")
    }
}

#Preview {
    WorkoutNoteEditor(noteBody: .constant(""))
        .padding()
        .background(BramColor.appBackground)
}
