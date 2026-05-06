import SwiftUI

struct WeeklyReviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Weekly Review")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(BramColor.textPrimary)

                BramCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A steady week.")
                            .font(.headline)
                            .foregroundStyle(BramColor.textPrimary)
                        Text("This screen will show one chart, one insight, and one suggested adjustment.")
                            .font(.subheadline)
                            .foregroundStyle(BramColor.textSecondary)
                    }
                }
            }
            .padding(20)
        }
        .background(BramColor.appBackground)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}
