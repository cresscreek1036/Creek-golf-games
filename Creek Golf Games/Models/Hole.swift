import Foundation
import SwiftData

/// A single hole on a course.
@Model
final class Hole {
    var id: UUID = UUID()
    var number: Int = 1
    var par: Int = 4
    /// Handicap ranking (1 = hardest hole), used for awarding strokes.
    var handicap: Int = 1

    var course: Course?

    init(number: Int, par: Int, handicap: Int) {
        self.number = number
        self.par = par
        self.handicap = handicap
    }
}
