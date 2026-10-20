//
//  DistanceFormatter.swift
//  donerkebabmap
//

import CoreLocation
import Foundation

/// Formats a distance for the user's region: in metric regions "300 m" below
/// 1 km and "1.2 km" above; imperial regions such as the US automatically
/// get feet/miles.
enum DistanceFormatter {
    /// Below 1 km: no decimals ("300 m").
    private static let coarse: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()

    /// 1 km and above: one decimal ("1.2 km").
    private static let fine: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()

    static func string(fromMeters meters: CLLocationDistance) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        return (meters < 1000 ? coarse : fine).string(from: measurement)
    }
}
