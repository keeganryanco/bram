import SwiftUI

struct HomeView: View {
    @State private var note: DailyWorkoutNote
    @State private var activePanel: HomePanel?

    init(note: DailyWorkoutNote = BramPreviewData.populatedNote) {
        _note = State(initialValue: note)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            BramColor.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeHeader(
                        date: note.date,
                        streakDays: note.metrics.streakDays,
                        openCalendar: { activePanel = .calendar },
                        openProgress: { activePanel = .progress },
                        openSettings: { activePanel = .settings }
                    )

                    WorkoutNoteEditor(noteBody: $note.body)

                    if let summary = note.parsedSummary {
                        ParsedWorkoutSummaryCard(summary: summary)
                    }

                    if let suggestion = note.suggestion {
                        WorkoutSuggestionCard(suggestion: suggestion)
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(daySwipeGesture)

            WorkoutLoadBar(metrics: note.metrics) {
                activePanel = .dayStats
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .font(BramFont.body())
        .sheet(item: $activePanel) { panel in
            panelView(for: panel)
                .presentationDetents(detents(for: panel))
                .presentationCornerRadius(30)
        }
    }

    @ViewBuilder
    private func panelView(for panel: HomePanel) -> some View {
        switch panel {
        case .calendar:
            CalendarPanelView(days: BramPreviewData.calendarDays, selectedDate: selectedDateBinding)
        case .dayStats:
            DailyWorkoutStatsPanelView(note: note)
        case .progress:
            StatsPanelView(stats: BramPreviewData.stats, initialMode: .stats)
        case .settings:
            SettingsView(account: BramPreviewData.account)
        }
    }

    private func detents(for panel: HomePanel) -> Set<PresentationDetent> {
        switch panel {
        case .calendar:
            [.medium, .large]
        case .dayStats:
            [.medium]
        case .progress, .settings:
            [.large]
        }
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { note.date },
            set: { newDate in
                withAnimation(.snappy) {
                    note.date = newDate
                }
            }
        )
    }

    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                guard abs(value.translation.width) > 60 else { return }
                navigateDay(by: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func navigateDay(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: note.date) else { return }
        withAnimation(.snappy) {
            note.date = newDate
        }
    }
}

#Preview("Home Dark") {
    HomeView()
        .preferredColorScheme(.dark)
}

#Preview("Home Empty Light") {
    HomeView(note: BramPreviewData.emptyNote)
        .preferredColorScheme(.light)
}
