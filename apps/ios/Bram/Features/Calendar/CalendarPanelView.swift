import SwiftUI

struct CalendarPanelView: View {
    let days: [CalendarWorkoutDay]
    @Binding var selectedDate: Date
    @State private var displayedMonth: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    init(days: [CalendarWorkoutDay], selectedDate: Binding<Date>) {
        self.days = days
        _selectedDate = selectedDate
        _displayedMonth = State(initialValue: Calendar.current.startOfMonth(for: selectedDate.wrappedValue))
    }

    var body: some View {
        BramPanelChrome(title: "Calendar") {
            CalendarMonthHeader(
                monthTitle: monthTitle,
                previousMonth: { moveMonth(by: -1) },
                nextMonth: { moveMonth(by: 1) },
                today: selectToday
            )

            BramCard(padding: 16) {
                VStack(spacing: 14) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(BramFont.label(size: 12))
                                .foregroundStyle(BramColor.textTertiary)
                        }

                        ForEach(monthDays) { day in
                            Button {
                                select(day.date)
                            } label: {
                                CalendarDayCell(day: day)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 18) {
                CalendarLegendItem(systemImage: "circle.fill", color: BramColor.violet, label: "Workout")
                CalendarLegendItem(systemImage: "star.fill", color: BramColor.energy, label: "PR")
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var monthDays: [CalendarPanelDay] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: displayedMonth)
        let leadingBlankDays = calendar.component(.weekday, from: startOfMonth) - 1
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingBlankDays, to: startOfMonth) else { return [] }

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            let marker = days.first { calendar.isDate($0.date, inSameDayAs: date) }
            return CalendarPanelDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                isToday: calendar.isDateInToday(date),
                hasWorkout: marker?.hasWorkout ?? false,
                hadPR: marker?.hadPR ?? false
            )
        }
    }

    private func moveMonth(by value: Int) {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(.snappy) {
            displayedMonth = Calendar.current.startOfMonth(for: nextMonth)
        }
    }

    private func selectToday() {
        select(.now)
    }

    private func select(_ date: Date) {
        withAnimation(.snappy) {
            selectedDate = date
            displayedMonth = Calendar.current.startOfMonth(for: date)
        }
    }
}

private struct CalendarLegendItem: View {
    let systemImage: String
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(BramFont.label())
                .foregroundStyle(BramColor.textSecondary)
        }
    }
}

private struct CalendarPanelDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let hasWorkout: Bool
    let hadPR: Bool

    var id: Date { date }
}

private struct CalendarMonthHeader: View {
    let monthTitle: String
    let previousMonth: () -> Void
    let nextMonth: () -> Void
    let today: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(BramColor.textPrimary)
            .accessibilityLabel("Previous month")

            Text(monthTitle)
                .font(BramFont.headline())
                .foregroundStyle(BramColor.textPrimary)

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(BramColor.textPrimary)
            .accessibilityLabel("Next month")

            Spacer()

            Button("Today", action: today)
                .font(BramFont.button(size: 14))
                .foregroundStyle(BramColor.violet)
                .buttonStyle(.plain)
        }
    }
}

private struct CalendarDayCell: View {
    let day: CalendarPanelDay

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

            Image(systemName: day.hadPR ? "star.fill" : "circle.fill")
                .font(.system(size: day.hadPR ? 7 : 5, weight: .bold))
                .foregroundStyle(dotColor)
                .frame(width: 8, height: 8)
                .opacity(day.hasWorkout ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var textColor: Color {
        if day.isSelected { return .white }
        return day.isInDisplayedMonth ? BramColor.textPrimary : BramColor.textTertiary.opacity(0.42)
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

    private var accessibilityLabel: String {
        var parts = [
            day.date.formatted(.dateTime.month(.wide).day().year())
        ]
        if day.isSelected { parts.append("selected") }
        if day.isToday { parts.append("today") }
        if day.hasWorkout { parts.append("workout logged") }
        if day.hadPR { parts.append("personal record") }
        return parts.joined(separator: ", ")
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}

#Preview {
    CalendarPanelView(days: BramPreviewData.calendarDays, selectedDate: .constant(.now))
        .preferredColorScheme(.dark)
}
