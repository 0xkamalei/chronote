import Foundation
import SwiftUI

/// Strategy for calculating adaptive time intervals for the timeline axis.
struct TimeAxisStrategy {
    struct Interval {
        let component: Calendar.Component
        let value: Int
        let labelFormat: String // e.g. "HH:mm"
        let showDate: Bool
    }
    
    /// Returns the best interval strategy based on visible duration
    static func calculateInterval(for range: ClosedRange<Date>, width: CGFloat) -> Interval {
        let duration = range.upperBound.timeIntervalSince(range.lowerBound)
        
        // Target: We want a label roughly every 100 pixels
        // maxLabels = width / 100
        // idealSecondsPerLabel = duration / maxLabels
        
        let idealSeconds = duration / (width / 100.0)
        
        // Define standard steps in seconds
        let minute = 60.0
        let hour = 3600.0
        
        if idealSeconds < 2 * minute {
            return Interval(component: .minute, value: 1, labelFormat: "HH:mm", showDate: false)
        } else if idealSeconds < 5 * minute {
            return Interval(component: .minute, value: 5, labelFormat: "HH:mm", showDate: false)
        } else if idealSeconds < 15 * minute {
            return Interval(component: .minute, value: 15, labelFormat: "HH:mm", showDate: false)
        } else if idealSeconds < 30 * minute {
            return Interval(component: .minute, value: 30, labelFormat: "HH:mm", showDate: false)
        } else if idealSeconds < 2 * hour {
            return Interval(component: .hour, value: 1, labelFormat: "HH:mm", showDate: false)
        } else if idealSeconds < 4 * hour {
            return Interval(component: .hour, value: 2, labelFormat: "HH:mm", showDate: false)
        } else if idealSeconds < 8 * hour {
            return Interval(component: .hour, value: 4, labelFormat: "HH:mm", showDate: false)
        } else if idealSeconds < 12 * hour {
            return Interval(component: .hour, value: 6, labelFormat: "HH:mm", showDate: true)
        } else if idealSeconds < 24 * hour {
            return Interval(component: .hour, value: 12, labelFormat: "dd HH:mm", showDate: true)
        } else {
            return Interval(component: .day, value: 1, labelFormat: "MM/dd", showDate: true)
        }
    }
    
    /// Generates dates based on the calculated interval
    static func generateTicks(range: ClosedRange<Date>, interval: Interval) -> [Date] {
        var ticks: [Date] = []
        let calendar = Calendar.current
        
        // Find first tick
        var date = range.lowerBound
        
        // Round up to nearest interval
        // Simple logic for standard components
        switch interval.component {
        case .minute:
            let minute = calendar.component(.minute, from: date)
            let remainder = minute % interval.value
            if remainder != 0 {
                date = calendar.date(byAdding: .minute, value: interval.value - remainder, to: date)!
            }
            date = calendar.date(bySetting: .second, value: 0, of: date)!
            
        case .hour:
            let hour = calendar.component(.hour, from: date)
            let remainder = hour % interval.value
            if remainder != 0 {
                date = calendar.date(byAdding: .hour, value: interval.value - remainder, to: date)!
            }
            date = calendar.date(bySetting: .minute, value: 0, of: date)!
            date = calendar.date(bySetting: .second, value: 0, of: date)!
            
        case .day:
            date = calendar.startOfDay(for: date)
            if date < range.lowerBound {
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
        default:
            break
        }
        
        // Generate loop
        while date <= range.upperBound {
            ticks.append(date)
            guard let next = calendar.date(byAdding: interval.component, value: interval.value, to: date) else { break }
            date = next
        }
        
        return ticks
    }
}
