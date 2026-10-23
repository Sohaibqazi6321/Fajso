import Foundation
import XCTest
@testable import FajsoCore

final class DistanceTests: XCTestCase {
    func testHaversineMatchesKnownCityPairs() throws {
        let london = Coordinate(latitude: 51.5074, longitude: -0.1278)
        let paris = Coordinate(latitude: 48.8566, longitude: 2.3522)
        let karachi = Coordinate(latitude: 24.8607, longitude: 67.0011)
        let chicago = Coordinate(latitude: 41.8781, longitude: -87.6298)

        XCTAssertEqual(try XCTUnwrap(Distance.meters(from: london, to: paris)) / 1_000, 343.5, accuracy: 3.5)
        XCTAssertEqual(try XCTUnwrap(Distance.meters(from: karachi, to: chicago)) / 1_000, 12_149, accuracy: 25)
        XCTAssertEqual(try XCTUnwrap(Distance.meters(from: london, to: london)), 0, accuracy: 0.001)
    }

    func testHaversineRejectsInvalidCoordinates() {
        let ok = Coordinate(latitude: 0, longitude: 0)
        XCTAssertNil(Distance.meters(from: ok, to: Coordinate(latitude: 91, longitude: 0)))
        XCTAssertNil(Distance.meters(from: ok, to: Coordinate(latitude: 0, longitude: .nan)))
    }

    func testKilometreFormatting() {
        XCTAssertEqual(DistanceFormatter.text(meters: 10, unit: .kilometers), "50 m")
        XCTAssertEqual(DistanceFormatter.text(meters: 349, unit: .kilometers), "350 m")
        XCTAssertEqual(DistanceFormatter.text(meters: 990, unit: .kilometers), "1.0 km")
        XCTAssertEqual(DistanceFormatter.text(meters: 4_240, unit: .kilometers), "4.2 km")
        XCTAssertEqual(DistanceFormatter.text(meters: 9_990, unit: .kilometers), "10 km")
        XCTAssertEqual(DistanceFormatter.text(meters: 1_284_300, unit: .kilometers), "1,284 km")
        XCTAssertEqual(DistanceFormatter.text(meters: 12_626_000, unit: .kilometers), "12,626 km")
    }

    func testMileFormattingKeepsTogetherAcceptanceValues() {
        // Values from the Together app's acceptance tests.
        XCTAssertEqual(DistanceFormatter.text(meters: 1 * 1_609.344, unit: .miles), "1.0 mi")
        XCTAssertEqual(DistanceFormatter.text(meters: 20 * 1_609.344, unit: .miles), "20 mi")
        XCTAssertEqual(DistanceFormatter.text(meters: 1_250 * 1_609.344, unit: .miles), "1,250 mi")
        XCTAssertEqual(DistanceFormatter.text(meters: 7_846 * 1_609.344, unit: .miles), "7,846 mi")
        XCTAssertEqual(DistanceFormatter.text(meters: 100, unit: .miles), "< 0.1 mi")
    }

    func testFormattingRejectsInvalidValues() {
        XCTAssertEqual(DistanceFormatter.text(meters: -1, unit: .kilometers), "—")
        XCTAssertEqual(DistanceFormatter.text(meters: .nan, unit: .miles), "—")
        XCTAssertEqual(DistanceFormatter.compactText(meters: .infinity, unit: .kilometers), "—")
    }

    func testCompactFormatting() {
        XCTAssertEqual(DistanceFormatter.compactText(meters: 349, unit: .kilometers), "350m")
        XCTAssertEqual(DistanceFormatter.compactText(meters: 4_240, unit: .kilometers), "4.2")
        XCTAssertEqual(DistanceFormatter.compactText(meters: 1_284_300, unit: .kilometers), "1,284")
    }

    func testFreshnessBoundaries() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func freshness(minutesAgo: Double) -> DistanceFreshness {
            DistanceFreshnessRules.freshness(sourceUpdatedAt: now.addingTimeInterval(-minutesAgo * 60), now: now)
        }
        XCTAssertEqual(freshness(minutesAgo: 29), .fresh)
        XCTAssertEqual(freshness(minutesAgo: 30), .aging)
        XCTAssertEqual(freshness(minutesAgo: 359), .aging)
        XCTAssertEqual(freshness(minutesAgo: 360), .stale)
        XCTAssertEqual(freshness(minutesAgo: -5), .fresh, "Clock skew into the future counts as fresh")
    }

    func testNextRefreshDate() {
        let source = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(
            DistanceFreshnessRules.nextRefreshDate(sourceUpdatedAt: source, now: source.addingTimeInterval(60)),
            source.addingTimeInterval(30 * 60)
        )
        XCTAssertEqual(
            DistanceFreshnessRules.nextRefreshDate(sourceUpdatedAt: source, now: source.addingTimeInterval(3_600)),
            source.addingTimeInterval(6 * 3_600)
        )
        let late = source.addingTimeInterval(7 * 3_600)
        XCTAssertEqual(DistanceFreshnessRules.nextRefreshDate(sourceUpdatedAt: source, now: late), late.addingTimeInterval(30 * 60))
    }

    func testAgeText() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(DistanceFormatter.ageText(since: now, now: now), "just now")
        XCTAssertEqual(DistanceFormatter.ageText(since: now.addingTimeInterval(-8 * 60), now: now), "8 min ago")
        XCTAssertEqual(DistanceFormatter.ageText(since: now.addingTimeInterval(-3 * 3_600), now: now), "3 h ago")
        XCTAssertEqual(DistanceFormatter.ageText(since: now.addingTimeInterval(-50 * 3_600), now: now), "2 d ago")
    }
}
