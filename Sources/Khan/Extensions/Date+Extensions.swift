import Foundation

public extension Date {
    
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
          lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
    
    static func + (lhs: Date, rhs: Date) -> TimeInterval {
          lhs.timeIntervalSinceReferenceDate + rhs.timeIntervalSinceReferenceDate
    }
    
    var dt: String {
        String(format: "%.0fms", millisSinceNow)
    }
    
    var millisSinceNow: Double {
        (Date() - self) * 1_000
    }
}
