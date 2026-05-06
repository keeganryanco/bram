import SwiftUI

struct TodayView: View {
    @State private var note = "Push day. Bench 185 for 3x8, last set hard."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Today")
                    .font(.system(size: 34, weight: .medium, design: .default))
                    .foregroundStyle(BramColor.textPrimary)

                BramCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workout note")
                            .font(.headline)
                            .foregroundStyle(BramColor.textPrimary)

                        TextEditor(text: $note)
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                            .font(.system(size: 17))
                            .foregroundStyle(BramColor.textPrimary)
                    }
                }

                BramCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bram will sort it out.")
                            .font(.headline)
                            .foregroundStyle(BramColor.textPrimary)
                        Text("The parser, structured summary, and suggestion engine will connect here after the local note loop is built.")
                            .font(.subheadline)
                            .foregroundStyle(BramColor.textSecondary)
                    }
                }
            }
            .padding(20)
        }
        .background(BramColor.appBackground)
        .navigationTitle("Bram")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
}
