import Testing
import Foundation
@testable import PanchangKit

// MARK: - Fixture model

private struct M1File: Decodable { let cases: [M1Case] }

private struct M1Case: Decodable {
    let id: String
    let lat: Double
    let lon: Double
    let tz: String
    let date_iso: String
    let sunrise: String
    let sunset: String
    let choghadiya: Cho
    let dur_muhurtam: [Window]
    let varjyam: Window
    let amrit_kalam: AmritField
    struct Cho: Decodable { let day: [Seg]; let night: [Seg] }
    struct Seg: Decodable { let name: String; let start: String; let end: String }
    struct Window: Decodable { let start: String; let end: String }
    /// amrit_kalam is a single object in some vectors, an array in others.
    enum AmritField: Decodable {
        case one(Window), many([Window])
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let arr = try? c.decode([Window].self) { self = .many(arr) }
            else { self = .one(try c.decode(Window.self)) }
        }
        var windows: [Window] { switch self { case .one(let w): return [w]; case .many(let a): return a } }
    }
}

private func loadM1() throws -> M1File {
    let url = Bundle.module.url(forResource: "m1_muhurta_vectors", withExtension: "json")
        ?? Bundle.module.url(forResource: "m1_muhurta_vectors", withExtension: "json", subdirectory: "Fixtures")
    guard let url else { Issue.record("m1_muhurta_vectors.json not found"); throw CocoaError(.fileNoSuchFile) }
    return try JSONDecoder().decode(M1File.self, from: try Data(contentsOf: url))
}

/// Parse "HH:MM" or "HH:MM+1" (local) to a Julian Day on the case date.
private func clock(_ s: String, y: Int, m: Int, d: Int, tz: TimeZone) -> Double? {
    var str = s.trimmingCharacters(in: .whitespaces)
    var plus = 0
    if str.contains("+1") { plus = 1; str = str.replacingOccurrences(of: "+1", with: "") }
    let hm = str.split(separator: ":")
    guard hm.count == 2, let h = Int(hm[0]), let mn = Int(hm[1]) else { return nil }
    var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
    var c = DateComponents(); c.year = y; c.month = m; c.day = d
    guard let base = cal.date(from: c), let shifted = cal.date(byAdding: .day, value: plus, to: base) else { return nil }
    let s2 = cal.dateComponents([.year, .month, .day], from: shifted)
    return JulianDate.julianDay(year: s2.year!, month: s2.month!, day: s2.day!, hour: h, minute: mn, timeZone: tz)
}

private func minutes(_ a: Double, _ b: Double) -> Double { abs(a - b) * 24 * 60 }

// MARK: - Tests

struct ChoghadiyaTests {

    /// Choghadiya names (exact) and segment boundaries (≤5 min, absorbing the SwiftAA-vs-drik
    /// sunrise/sunset model gap) match drikpanchang for every validation vector.
    @Test func matchesReferenceVectors() throws {
        let file = try loadM1()
        for c in file.cases {
            let p = c.date_iso.split(separator: "-").compactMap { Int($0) }
            guard p.count == 3 else { Issue.record("\(c.id) bad date"); continue }
            let loc = GeoLocation(latitude: c.lat, longitude: c.lon, timeZoneIdentifier: c.tz)
            let tz = loc.timeZone
            let day = Panchang().compute(year: p[0], month: p[1], day: p[2], location: loc, config: .gujaratiWestern)

            for (half, expected) in [("day", c.choghadiya.day), ("night", c.choghadiya.night)] {
                let got = half == "day" ? day.choghadiya.day : day.choghadiya.night
                #expect(got.count == expected.count, "\(c.id) \(half) count")
                for (i, e) in expected.enumerated() where i < got.count {
                    #expect(got[i].name == e.name, "\(c.id) \(half)[\(i)] name \(got[i].name) != \(e.name)")
                    if let es = clock(e.start, y: p[0], m: p[1], d: p[2], tz: tz) {
                        #expect(minutes(got[i].start, es) <= 5, "\(c.id) \(half)[\(i)] start off by \(minutes(got[i].start, es))")
                    }
                    if let ee = clock(e.end, y: p[0], m: p[1], d: p[2], tz: tz) {
                        #expect(minutes(got[i].end, ee) <= 5, "\(c.id) \(half)[\(i)] end off by \(minutes(got[i].end, ee))")
                    }
                }
            }
        }
    }

    /// Dur Muhurtam windows match drikpanchang (≤5 min on each bound) for every vector. The
    /// fixture lists day windows then night; match as a set since order is incidental.
    @Test func durMuhurtamMatchesReferenceVectors() throws {
        let file = try loadM1()
        for c in file.cases {
            let p = c.date_iso.split(separator: "-").compactMap { Int($0) }
            let loc = GeoLocation(latitude: c.lat, longitude: c.lon, timeZoneIdentifier: c.tz)
            let tz = loc.timeZone
            let day = Panchang().compute(year: p[0], month: p[1], day: p[2], location: loc, config: .gujaratiWestern)
            let got = day.durMuhurtam
            #expect(got.count == c.dur_muhurtam.count, "\(c.id) dur muhurtam count \(got.count) != \(c.dur_muhurtam.count)")
            for e in c.dur_muhurtam {
                guard let es = clock(e.start, y: p[0], m: p[1], d: p[2], tz: tz),
                      let ee = clock(e.end, y: p[0], m: p[1], d: p[2], tz: tz) else { continue }
                let match = got.contains { w in
                    guard let ws = w.start, let we = w.end else { return false }
                    return minutes(ws, es) <= 5 && minutes(we, ee) <= 5
                }
                #expect(match, "\(c.id) no Dur Muhurtam window near \(e.start)-\(e.end)")
            }
        }
    }

    /// Varjyam and Amrit Kalam windows match drikpanchang (≤5 min each bound) for every vector,
    /// including the day (sj-03-09) that carries two Amrit windows from different nakshatras.
    @Test func varjyamAndAmritMatchReferenceVectors() throws {
        let file = try loadM1()
        for c in file.cases {
            let p = c.date_iso.split(separator: "-").compactMap { Int($0) }
            let loc = GeoLocation(latitude: c.lat, longitude: c.lon, timeZoneIdentifier: c.tz)
            let tz = loc.timeZone
            let day = Panchang().compute(year: p[0], month: p[1], day: p[2], location: loc, config: .gujaratiWestern)

            func check(_ expected: [M1Case.Window], _ got: [MuhurtaWindow], _ label: String) {
                #expect(got.count == expected.count, "\(c.id) \(label) count \(got.count) != \(expected.count)")
                for e in expected {
                    guard let es = clock(e.start, y: p[0], m: p[1], d: p[2], tz: tz),
                          let ee = clock(e.end, y: p[0], m: p[1], d: p[2], tz: tz) else { continue }
                    let match = got.contains { w in
                        guard let ws = w.start, let we = w.end else { return false }
                        return minutes(ws, es) <= 5 && minutes(we, ee) <= 5
                    }
                    #expect(match, "\(c.id) no \(label) window near \(e.start)-\(e.end)")
                }
            }
            check([c.varjyam], day.varjyam, "varjyam")
            check(c.amrit_kalam.windows, day.amritKalam, "amrit")
        }
    }

    /// The 16 segments tile sunrise→next-sunrise with no gaps/overlaps; the interval is ~24h
    /// (NOT exactly 24h — do not assert == 24h, per SPEC2 §M1).
    @Test func sixteenSegmentsCoverDayWithoutGaps() throws {
        let file = try loadM1()
        for c in file.cases {
            let p = c.date_iso.split(separator: "-").compactMap { Int($0) }
            let loc = GeoLocation(latitude: c.lat, longitude: c.lon, timeZoneIdentifier: c.tz)
            let day = Panchang().compute(year: p[0], month: p[1], day: p[2], location: loc, config: .gujaratiWestern)
            let segs = day.choghadiya.day + day.choghadiya.night
            #expect(segs.count == 16, "\(c.id) segment count")
            for i in 1..<segs.count {
                #expect(minutes(segs[i].start, segs[i - 1].end) < 0.001, "\(c.id) gap before segment \(i)")
            }
            #expect(minutes(day.choghadiya.day[0].start, day.timings.sunrise!) < 0.001, "\(c.id) day starts at sunrise")
            #expect(minutes(day.choghadiya.day[7].end, day.timings.sunset!) < 0.001, "\(c.id) day ends at sunset")
            let total = (segs.last!.end - segs.first!.start) * 24
            #expect(total > 23 && total < 25, "\(c.id) full span ~24h, got \(total)h")
        }
    }

    /// Hora: 24 hours, equal within each half (12 + 12), contiguous, first hora = weekday lord,
    /// and the 25th hour rolls over to the next weekday's lord.
    @Test func horasAreEqualDurationAndRollOver() throws {
        let file = try loadM1()
        for c in file.cases {
            let p = c.date_iso.split(separator: "-").compactMap { Int($0) }
            let loc = GeoLocation(latitude: c.lat, longitude: c.lon, timeZoneIdentifier: c.tz)
            let day = Panchang().compute(year: p[0], month: p[1], day: p[2], location: loc, config: .gujaratiWestern)
            let h = day.horas
            #expect(h.count == 24, "\(c.id) hora count")

            let dayUnit = h[0].end - h[0].start
            let nightUnit = h[12].end - h[12].start
            for i in 0..<12 { #expect(abs((h[i].end - h[i].start) - dayUnit) * 24 * 60 < 0.01, "\(c.id) day hora \(i)") }
            for i in 12..<24 { #expect(abs((h[i].end - h[i].start) - nightUnit) * 24 * 60 < 0.01, "\(c.id) night hora \(i)") }
            for i in 1..<24 { #expect(minutes(h[i].start, h[i - 1].end) < 0.001, "\(c.id) hora gap at \(i)") }

            #expect(h[0].planet == HoraCalc.chaldean[HoraCalc.weekdayLord[day.vara.index]], "\(c.id) first hora lord")
            // 25th hora (next sunrise) is the next weekday's lord.
            let nextLord = HoraCalc.chaldean[HoraCalc.weekdayLord[(day.vara.index + 1) % 7]]
            let h24 = HoraCalc.chaldean[(HoraCalc.weekdayLord[day.vara.index] + 24) % 7]
            #expect(h24 == nextLord, "\(c.id) hora rollover")
        }
    }
}
