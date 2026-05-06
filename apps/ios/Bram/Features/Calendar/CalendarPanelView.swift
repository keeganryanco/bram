import SwiftUI

struct CalendarPanelView: View {
    let days: [CalendarWorkoutDay]
    let selectedDate: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        BramPanelChrome(title: "Calendar") {
            HStack {
                Text(monthTitle)
                    .font(BramFont.headline())
                    .foregroundStyle(BramColor.textPrimary)
                Spacer()
                Button("Today") {}
                    .font(BramFont.button(size: 14))
                    .foregroundStyle(BramColor.violet)
                    .buttonStyle(.plain)
            }

            BramCard(padding: 16) {
                VStack(spacing: 14) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(BramFont.label(size: 12))
                                .foregroundStyle(BramColor.textTertiary)
                        }

                        ForEach(days) { day in
                            CalendarDayCell(day: day)
                        }
                    }
                }
            }

            BramCard {
                Label("Completed workout days use quiet dots; PR days add a small orange mark.", systemImage: "circle.grid.3x3.fill")
                    .font(BramFont.callout())
                    .foregroundStyle(BramColor.textSecondary)
            }
        }
    }

    private var monthTitle: String {
        selectedDate.formatted(.dateTime.month(.wide).year())
    }
}

private struct CalendarDayCell: View {
    let day: CalendarWorkoutDay

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day.date))")
                .font(BramFont.label(size: 14))
                .foregroundStyle(textColor)
                .frame(width: 34, height: 34)
                .background(selectionBackground)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(selectionStroke, lineWidth: day.isSelected ? 2 : 1)
                }

            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
                .opacity(day.hasWorkout ? 1 : 0)
        }
    }

    private var textColor: Color {
        day.isSelected ? .white : BramColor.textPrimary
    }

    private var selectionBackground: Color {
        day.isSelected ? BramColor.violet : .clear
    }

    private var selectionStroke: Color {
        if day.isSelected { return BramColor.violet }
        if day.isToday { return BramColor.hairline }
        return .clear
    }

    private var dotColor: Color {
        day.hadPR ? BramColor.energy : BramColor.violet
    }
}

#Preview {
    CalendarPanelView(days: BramPreviewData.calendarDays, selectedDate: .now)
        .preferredColorScheme(.dark)
}
