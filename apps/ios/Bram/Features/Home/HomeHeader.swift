import SwiftUI

struct HomeHeader: View {
    let date: Date
    let streakDays: Int
    let openCalendar: () -> Void
    let openProgress: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            BramLogoMark(size: 44)
                .frame(width: 76, alignment: .leading)

            Spacer()

            BramCapsuleButton(action: openCalendar) {
                Text(dateLabel)
            }
            .accessibilityLabel("Open calendar")

            Spacer()

            HStack(spacing: 8) {
                Button(action: openProgress) {
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
    HomeHeader(date: .now, streakDays: 4, openCalendar: {}, openProgress: {}, openSettings: {})
        .padding()
        .background(BramColor.appBackground)
}
