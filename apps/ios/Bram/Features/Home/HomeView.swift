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

            WorkoutLoadBar(metrics: note.metrics) {
                activePanel = .stats
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
            CalendarPanelView(days: BramPreviewData.calendarDays, selectedDate: note.date)
        case .stats:
            StatsPanelView(stats: BramPreviewData.stats)
        case .settings:
            SettingsView(account: BramPreviewData.account)
        }
    }

    private func detents(for panel: HomePanel) -> Set<PresentationDetent> {
        switch panel {
        case .calendar:
            [.medium, .large]
        case .stats, .settings:
            [.large]
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
