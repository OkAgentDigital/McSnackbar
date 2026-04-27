import Foundation

struct Schedule: Codable {
    var isEnabled: Bool = false
    var timeInterval: TimeIntervalType = .daily
    var specificTime: DateComponents?
    var daysOfWeek: [Int] = []
    
    enum TimeIntervalType: String, Codable, CaseIterable {
        case hourly
        case daily
        case weekly
        case specificTime
    }
    
    func nextRunDate(after date: Date = Date()) -> Date? {
        guard isEnabled else { return nil }
        let calendar = Calendar.current
        
        switch timeInterval {
        case .hourly:
            return calendar.date(byAdding: .hour, value: 1, to: date)
        case .daily:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!
            return calendar.date(bySettingHour: specificTime?.hour ?? 9, minute: specificTime?.minute ?? 0, second: 0, of: tomorrow)
        case .weekly:
            guard let specificTime = specificTime, !daysOfWeek.isEmpty else { return nil }
            let currentWeekday = calendar.component(.weekday, from: date)
            for dayOffset in 1...7 {
                let nextWeekday = (currentWeekday + dayOffset - 1) % 7 + 1
                if daysOfWeek.contains(nextWeekday) {
                    let nextDate = calendar.date(byAdding: .day, value: dayOffset, to: date)!
                    return calendar.date(bySettingHour: specificTime.hour ?? 9, minute: specificTime.minute ?? 0, second: 0, of: nextDate)
                }
            }
        case .specificTime:
            guard let specificTime = specificTime else { return nil }
            let todayAtTime = calendar.date(bySettingHour: specificTime.hour ?? 9, minute: specificTime.minute ?? 0, second: 0, of: date)!
            return todayAtTime > date ? todayAtTime : calendar.date(byAdding: .day, value: 1, to: todayAtTime)
        }
        return nil
    }
}