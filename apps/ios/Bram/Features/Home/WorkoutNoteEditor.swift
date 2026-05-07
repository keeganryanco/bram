import SwiftUI

struct WorkoutNoteEditor: View {
    @Binding var noteBody: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Write what you did. Bram will sort it out.", text: $noteBody, axis: .vertical)
            .focused($isFocused)
            .font(BramFont.body(size: 20))
            .foregroundStyle(BramColor.textPrimary)
            .tint(BramColor.violet)
            .lineLimit(12...240)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 270, alignment: .topLeading)
            .padding(.top, 20)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .accessibilityLabel("Workout note")
    }
}

#Preview {
    WorkoutNoteEditor(noteBody: .constant(""))
        .padding()
        .background(BramColor.appBackground)
}
