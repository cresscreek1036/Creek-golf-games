import Foundation
import SwiftData

/// One group's round at a course on a given day.
@Model
final class Round {
    var id: UUID = UUID()
    var date: Date = Date.now
    var groupName: String = ""
    var isComplete: Bool = false

    var course: Course?

    @Relationship(deleteRule: .nullify, inverse: \Player.rounds)
    var players: [Player]? = []

    /// Deleting a round deletes its hole scores.
    @Relationship(deleteRule: .cascade, inverse: \Score.round)
    var scores: [Score]? = []

    init(course: Course?, players: [Player] = [], groupName: String = "", date: Date = .now) {
        self.course = course
        self.players = players
        self.groupName = groupName
        self.date = date
    }

    /// The score a player made on a given hole, if entered.
    func score(for player: Player, hole: Int) -> Score? {
        (scores ?? []).first { $0.player?.id == player.id && $0.holeNumber == hole }
    }

    /// Total strokes for a player across all entered holes.
    func totalStrokes(for player: Player) -> Int {
        (scores ?? [])
            .filter { $0.player?.id == player.id }
            .reduce(0) { $0 + $1.strokes }
    }
}
