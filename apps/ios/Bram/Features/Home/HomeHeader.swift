import SwiftUI

struct HomeHeader: View {
    let date: Date
    let streakDays: Int
    let openCalendar: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("Bram")
                .font(BramFont.wordmark(size: 30))
                .foregroundStyle(BramColor.violet)
                .frame(width: 76, alignment: .leading)

            Spacer()

            BramCapsuleButton(action: openCalendar) {
                Text(dateLabel)
            }
            .accessibilityLabel("Open calendar")

            Spacer()

            HStack(spacing: 8) {
                Button(action: openCalendar) {
                    Label("\(streakDays)", systemImage: "flame.fill")
                        .labelStyle(.titleAndIcon)
                        .font(BramFont.button())
                        .foregroundStyle(BramColor.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(streakDays) day streak")

                Divider()
                    .frame(height: 18)

                Button(action: openSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BramColor.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open settings")
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(BramColor.elevated)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(BramColor.hairline, lineWidth: 1)
            }
        }
    }

    private var dateLabel: String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview {
    HomeHeader(date: .now, streakDays: 4, openCalendar: {}, openSettings: {})
        .padding()
        .background(BramColor.appBackground)
}
