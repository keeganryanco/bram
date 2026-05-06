import SwiftUI

struct TodayView: View {
    @State private var note = "Push day. Bench 185 for 3x8, last set hard."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Today")
                    .font(BramFont.largeTitle())
                    .foregroundStyle(BramColor.textPrimary)

                BramCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workout note")
                            .font(BramFont.headline())
                            .foregroundStyle(BramColor.textPrimary)

                        TextEditor(text: $note)
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                            .font(BramFont.body())
                            .foregroundStyle(BramColor.textPrimary)
                    }
                }

                BramCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bram will sort it out.")
                            .font(BramFont.headline())
                            .foregroundStyle(BramColor.textPrimary)
                        Text("The parser, structured summary, and suggestion engine will connect here after the local note loop is built.")
                            .font(BramFont.callout())
                            .foregroundStyle(BramColor.textSecondary)
                    }
                }
            }
            .padding(20)
        }
        .background(BramColor.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Bram")
                    .font(BramFont.wordmark(size: 24))
                    .foregroundStyle(BramColor.violet)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
}
