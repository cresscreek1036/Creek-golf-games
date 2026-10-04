import Foundation
import SwiftData

/// A player's stroke count on one hole of a round.
@Model
final class Score {
    var id: UUID = UUID()
    var holeNumber: Int = 1
    var strokes: Int = 0

    var round: Round?
    var player: Player?

    init(round: Round, player: Player, holeNumber: Int, strokes: Int) {
        self.round = round
        self.player = player
        self.holeNumber = holeNumber
        self.strokes = strokes
    }
}
