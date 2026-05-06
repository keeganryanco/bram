import SwiftUI

struct ProgressView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Progress")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(BramColor.textPrimary)

                BramCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress without spreadsheets.")
                            .font(.headline)
                            .foregroundStyle(BramColor.textPrimary)
                        Text("Exercise history, PRs, volume, and consistency trends will live here.")
                            .font(.subheadline)
                            .foregroundStyle(BramColor.textSecondary)
                    }
                }
            }
            .padding(20)
        }
        .background(BramColor.appBackground)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
}
