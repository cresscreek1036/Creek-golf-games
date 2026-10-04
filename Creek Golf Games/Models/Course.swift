import Foundation
import SwiftData

/// A golf course and its holes.
///
/// All properties have defaults and all relationships are optional so the
/// model is compatible with CloudKit sync.
@Model
final class Course {
    var id: UUID = UUID()
    var name: String = ""
    var city: String = ""

    /// Deleting a course deletes its holes.
    @Relationship(deleteRule: .cascade, inverse: \Hole.course)
    var holes: [Hole]? = []

    /// Deleting a course keeps past rounds; they just lose their course link.
    @Relationship(deleteRule: .nullify, inverse: \Round.course)
    var rounds: [Round]? = []

    init(name: String, city: String = "") {
        self.name = name
        self.city = city
    }

    /// Holes ordered by hole number.
    var sortedHoles: [Hole] {
        (holes ?? []).sorted { $0.number < $1.number }
    }

    /// Total par for the course.
    var par: Int {
        (holes ?? []).reduce(0) { $0 + $1.par }
    }
}
