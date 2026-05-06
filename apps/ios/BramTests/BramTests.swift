import Testing
@testable import Bram

struct BramTests {
    @Test func workoutNoteDefaultsToEmptyBody() {
        let note = WorkoutNote()
        #expect(note.body.isEmpty)
    }
}
