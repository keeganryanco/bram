import Foundation

struct WorkoutNote: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var body: String

    init(id: UUID = UUID(), date: Date = .now, body: String = "") {
        self.id = id
        self.date = date
        self.body = body
    }
}
