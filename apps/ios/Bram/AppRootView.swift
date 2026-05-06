import SwiftUI

struct AppRootView: View {
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
            }
            .tag(AppTab.today)

            NavigationStack {
                ProgressView()
            }
            .tabItem {
                Label(AppTab.progress.title, systemImage: AppTab.progress.systemImage)
            }
            .tag(AppTab.progress)

            NavigationStack {
                WeeklyReviewView()
            }
            .tabItem {
                Label(AppTab.review.title, systemImage: AppTab.review.systemImage)
            }
            .tag(AppTab.review)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
            }
            .tag(AppTab.settings)
        }
        .tint(BramColor.violet)
        .font(BramFont.body())
    }
}

enum AppTab: Hashable {
    case today
    case progress
    case review
    case settings

    var title: String {
        switch self {
        case .today: "Today"
        case .progress: "Progress"
        case .review: "Review"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "note.text"
        case .progress: "chart.line.uptrend.xyaxis"
        case .review: "calendar"
        case .settings: "gearshape"
        }
    }
}

#Preview {
    AppRootView()
}
