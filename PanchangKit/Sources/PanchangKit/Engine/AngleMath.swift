import Foundation

/// Small numeric helpers shared across the engine. All angles are in degrees unless noted.
enum AngleMath {
    /// Normalize an angle to the half-open range [0, 360).
    static func normalize360(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// Normalize an angle to (-180, 180].
    static func normalize180(_ degrees: Double) -> Double {
        var d = normalize360(degrees)
        if d > 180 { d -= 360 }
        return d
    }

    /// Find the Julian Day at which a monotonically-increasing angle (mod `period`)
    /// reaches `targetValue`, by bracketing and bisection.
    ///
    /// `angleAt(jd)` must return the *unwrapped, increasing* quantity in degrees (Moon and
    /// Sun longitudes always advance, so the relevant panchang angles increase with time).
    /// We search forward from `startJD` in `step`-day increments until the target is bracketed,
    /// then bisect to `tolerance` (days). This is the established end-time solving approach
    /// (drik-panchanga uses inverse Lagrange interpolation; bisection on the same monotone
    /// function reaches the same root and is simpler to reason about and test).
    static func solveCrossing(
        targetValue: Double,
        startJD: Double,
        step: Double,
        maxSpan: Double,
        tolerance: Double = 1.0 / 86400.0, // ~1 second
        angleAt: (Double) -> Double
    ) -> Double? {
        var lo = startJD
        var loVal = angleAt(lo)
        var travelled = 0.0
        while travelled < maxSpan {
            let hi = lo + step
            let hiVal = angleAt(hi)
            if loVal <= targetValue && targetValue <= hiVal {
                return bisect(targetValue: targetValue, lo: lo, hi: hi, tolerance: tolerance, angleAt: angleAt)
            }
            lo = hi
            loVal = hiVal
            travelled += step
        }
        return nil
    }

    private static func bisect(
        targetValue: Double,
        lo: Double,
        hi: Double,
        tolerance: Double,
        angleAt: (Double) -> Double
    ) -> Double {
        var lo = lo
        var hi = hi
        while hi - lo > tolerance {
            let mid = (lo + hi) / 2
            if angleAt(mid) < targetValue {
                lo = mid
            } else {
                hi = mid
            }
        }
        return (lo + hi) / 2
    }
}
