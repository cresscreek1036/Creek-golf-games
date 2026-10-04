import Foundation
import SwiftData

/// A golfer who can be added to rounds.
@Model
final class Player {
    var id: UUID = UUID()
    var name: String = ""
    var handicapIndex: Double = 0

    /// Rounds this player took part in (many-to-many with `Round.players`).
    var rounds: [Round]? = []

    /// Deleting a player removes their hole scores.
    @Relationship(deleteRule: .cascade, inverse: \Score.player)
    var scores: [Score]? = []

    init(name: String, handicapIndex: Double = 0) {
        self.name = name
        self.handicapIndex = handicapIndex
    }
}
