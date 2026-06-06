import Foundation
import Observation
import PanchangKit

/// Computes a kundli (planetary positions + Vimshottari dasha) for a birth profile, off the
/// main actor. Pure-engine work via `Astrology`.
@Observable
@MainActor
final class KundliViewModel {
    enum LoadState {
        case empty                 // no birth profile yet
        case loading
        case loaded(PlanetaryPositions, VimshottariDasha)
    }

    var state: LoadState = .empty

    func load(birthInstant: Date, location: GeoLocation) {
        state = .loading
        let birth = birthInstant
        let loc = location
        Task.detached(priority: .userInitiated) {
            let astro = Astrology()
            let jd = JulianDate.julianDay(from: birth)
            let positions = astro.positions(julianDay: jd, location: loc)
            let dasha = astro.dasha(birth: birth)
            await MainActor.run { self.state = .loaded(positions, dasha) }
        }
    }
}
