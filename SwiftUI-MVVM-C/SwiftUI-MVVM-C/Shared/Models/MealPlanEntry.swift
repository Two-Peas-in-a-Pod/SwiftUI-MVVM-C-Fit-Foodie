//
//  MealPlanEntry.swift
//  SwiftUI-MVVM-C
//

import Foundation
import SwiftData

/// Represents a single meal assigned to a specific day in a specific week.
/// `weekStartDate` is always normalized to the Monday of that week at midnight.
@Model
class MealPlanEntry {
    var id: UUID
    /// Monday of the week this entry belongs to (normalized to midnight).
    var weekStartDate: Date
    /// 0 = Monday … 6 = Sunday
    var dayOffset: Int
    var recipe: Recipe?
    /// EKEvent identifier stored so the calendar event can be removed when the meal is changed.
    var calendarEventId: String?

    init(weekStartDate: Date, dayOffset: Int, recipe: Recipe? = nil) {
        self.id = UUID()
        self.weekStartDate = weekStartDate
        self.dayOffset = dayOffset
        self.recipe = recipe
        self.calendarEventId = nil
    }

    /// The calendar date this entry falls on.
    var date: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStartDate) ?? weekStartDate
    }
}

// MARK: - Week helpers

extension Date {
    /// Returns the Monday of the week containing this date, normalized to midnight local time.
    var startOfWeek: Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: comps) ?? self
    }
}
