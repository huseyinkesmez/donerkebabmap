//
//  DistanceFormatter.swift
//  donerkebabmap
//

import CoreLocation
import Foundation

/// Mesafeyi kullanıcının bölgesine göre biçimlendirir: metrik bölgelerde
/// 1 km altında "300 m", üstünde "1,2 km"; ABD gibi imperial bölgelerde
/// otomatik olarak feet/mil kullanılır.
enum DistanceFormatter {
    /// 1 km altı: ondalık gösterme ("300 m").
    private static let coarse: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()

    /// 1 km ve üstü: tek ondalık ("1,2 km").
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
