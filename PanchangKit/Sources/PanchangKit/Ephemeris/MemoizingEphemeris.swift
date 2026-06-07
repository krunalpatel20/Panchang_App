import Foundation

/// An `Ephemeris` decorator that memoizes results for the lifetime of one engine computation.
///
/// The panchang/astrology engines evaluate the same instants over and over: every limb reads
/// Sun/Moon longitude at the same sunrise anchor; `solveCrossing` for tithi and karana walk the
/// *same* forward grid from that anchor; new-moon solving in `masa` and `year` runs the identical
/// bisection from the same Julian Day; the samvatsara walk-back revisits the same months; and the
/// rise/set anchor sweeps of adjacent days overlap by three of four anchors. Because all of these
/// land on bit-identical Julian Days (same arithmetic from the same start), caching by exact JD
/// turns the redundant work into dictionary hits and leaves results unchanged.
///
/// Create one per top-level `compute()`. It is scoped to a single computation and thread; the lock
/// exists only to satisfy the `Ephemeris: Sendable` contract (contention is effectively zero).
final class MemoizingEphemeris: Ephemeris, @unchecked Sendable {
    private let base: Ephemeris
    private let lock = NSLock()

    private var sunLon: [Double: Double] = [:]
    private var moonLon: [Double: Double] = [:]
    private var grahaLon: [String: Double] = [:]
    private var node: [Double: Double] = [:]
    private var gast: [Double: Double] = [:]
    private var obliquity: [Double: Double] = [:]
    private var riseSet: [String: RiseSet] = [:]

    init(base: Ephemeris) { self.base = base }

    private func cached<K: Hashable>(_ key: K, in store: inout [K: Double], compute: () -> Double) -> Double {
        lock.lock(); defer { lock.unlock() }
        if let v = store[key] { return v }
        let v = compute()
        store[key] = v
        return v
    }

    func sunLongitude(julianDay jd: Double) -> Double {
        cached(jd, in: &sunLon) { base.sunLongitude(julianDay: jd) }
    }

    func moonLongitude(julianDay jd: Double) -> Double {
        cached(jd, in: &moonLon) { base.moonLongitude(julianDay: jd) }
    }

    func longitude(of graha: Graha, julianDay jd: Double) -> Double {
        cached("\(graha.rawValue):\(jd)", in: &grahaLon) { base.longitude(of: graha, julianDay: jd) }
    }

    func lunarNodeLongitude(julianDay jd: Double) -> Double {
        cached(jd, in: &node) { base.lunarNodeLongitude(julianDay: jd) }
    }

    func greenwichApparentSiderealTime(julianDay jd: Double) -> Double {
        cached(jd, in: &gast) { base.greenwichApparentSiderealTime(julianDay: jd) }
    }

    func obliquityOfEcliptic(julianDay jd: Double) -> Double {
        cached(jd, in: &obliquity) { base.obliquityOfEcliptic(julianDay: jd) }
    }

    func riseTransitSet(body: Body, anchorJulianDay jd: Double, location: GeoLocation) -> RiseSet {
        let key = "\(body):\(jd):\(location.latitude):\(location.longitude)"
        lock.lock(); defer { lock.unlock() }
        if let v = riseSet[key] { return v }
        let v = base.riseTransitSet(body: body, anchorJulianDay: jd, location: location)
        riseSet[key] = v
        return v
    }
}
