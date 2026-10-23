import Foundation

// Platform-independent distance logic, shared by the app and the widget and
// tested on Linux/Windows through Package.swift. Foundation only: no CoreLocation,
// no SwiftUI.
// Freshness rules are carried over from the earlier Together app.

public struct Coordinate: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

public enum Distance {
    /// Mean Earth radius (IUGG), metres.
    static let earthRadiusMeters = 6_371_008.8

    /// Great-circle distance in metres (haversine). Returns nil for invalid input.
    public static func meters(from a: Coordinate, to b: Coordinate) -> Double? {
        guard a.isValid, b.isValid else { return nil }
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }
}

public enum DistanceUnit: String, Codable, Sendable {
    case kilometers
    case miles
}

public enum DistanceFreshness: Equatable, Sendable {
    case fresh   // under 30 minutes old
    case aging   // under 6 hours old
    case stale   // older than that
}

public enum DistanceFreshnessRules {
    public static let freshInterval: TimeInterval = 30 * 60
    public static let staleInterval: TimeInterval = 6 * 60 * 60

    /// Freshness of a distance whose *oldest* source location was recorded at `sourceUpdatedAt`.
    public static func freshness(sourceUpdatedAt: Date, now: Date) -> DistanceFreshness {
        let age = max(0, now.timeIntervalSince(sourceUpdatedAt))
        if age < freshInterval { return .fresh }
        if age < staleInterval { return .aging }
        return .stale
    }

    /// When a widget should next re-render so its freshness label stays honest.
    public static func nextRefreshDate(sourceUpdatedAt: Date, now: Date) -> Date {
        let freshBoundary = sourceUpdatedAt.addingTimeInterval(freshInterval)
        if now < freshBoundary { return freshBoundary }
        let staleBoundary = sourceUpdatedAt.addingTimeInterval(staleInterval)
        if now < staleBoundary { return staleBoundary }
        return now.addingTimeInterval(freshInterval)
    }
}

public enum DistanceFormatter {
    /// Within this distance, with both locations fresh, we show "Together".
    public static let togetherThresholdMeters = 100.0

    static let metersPerMile = 1_609.344

    /// "350 m", "4.2 km", "1,284 km", "0.3 mi", "12 mi".
    public static func text(meters: Double, unit: DistanceUnit) -> String {
        guard meters.isFinite, meters >= 0 else { return "—" }
        switch unit {
        case .kilometers:
            if meters < 1_000 {
                let rounded = max(50, (meters / 50).rounded() * 50)
                return rounded >= 1_000 ? "1.0 km" : "\(Int(rounded)) m"
            }
            return value(meters / 1_000) + " km"
        case .miles:
            let miles = meters / metersPerMile
            if miles < 0.1 { return "< 0.1 mi" }
            return value(miles) + " mi"
        }
    }

    /// Number only, for tight Lock Screen layouts: "4.2", "1,284", "350m".
    public static func compactText(meters: Double, unit: DistanceUnit) -> String {
        guard meters.isFinite, meters >= 0 else { return "—" }
        switch unit {
        case .kilometers:
            if meters < 1_000 { return "\(Int(max(50, (meters / 50).rounded() * 50)))m" }
            return value(meters / 1_000)
        case .miles:
            let miles = meters / metersPerMile
            return miles < 0.1 ? "<0.1" : value(miles)
        }
    }

    /// "just now", "8 min ago", "3 h ago", "2 d ago".
    public static func ageText(since date: Date, now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) h ago" }
        return "\(hours / 24) d ago"
    }

    /// One decimal under 10, whole numbers with thousands separators above.
    static func value(_ amount: Double) -> String {
        if amount < 10 {
            let tenths = (amount * 10).rounded()
            if tenths < 100 {
                return "\(Int(tenths) / 10).\(Int(tenths) % 10)"
            }
        }
        return grouped(Int(amount.rounded()))
    }

    /// Locale-independent grouping ("1,284") so output is identical on every platform.
    static func grouped(_ number: Int) -> String {
        let digits = String(number)
        var result = ""
        for (index, character) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { result.append(",") }
            result.append(character)
        }
        return result
    }
}
