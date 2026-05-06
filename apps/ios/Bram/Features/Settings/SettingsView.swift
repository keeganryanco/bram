import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("Account") {
                Label("Sign in", systemImage: "person.crop.circle")
                Label("Subscription", systemImage: "creditcard")
            }

            Section("Privacy") {
                Link(destination: URL(string: "https://trybram.app/privacy")!) {
                    Label("Privacy Policy", systemImage: "lock")
                }
                Link(destination: URL(string: "https://trybram.app/terms")!) {
                    Label("Terms and Conditions", systemImage: "doc.text")
                }
                Link(destination: URL(string: "mailto:support@trybram.app")!) {
                    Label("Contact Support", systemImage: "envelope")
                }
            }
        }
        .font(BramFont.body())
        .scrollContentBackground(.hidden)
        .background(BramColor.appBackground)
        .navigationTitle("Settings")
    }
}
