//
//  MealPlanCalendarService.swift
//  SwiftUI-MVVM-C
//

import EventKit
import Foundation

/// Manages adding meal plan entries to the user's iOS Calendar.
/// Uses a dedicated "Meal Plan" calendar so events are easy to find and remove.
@MainActor
final class MealPlanCalendarService: ObservableObject {
    static let shared = MealPlanCalendarService()

    private let store = EKEventStore()
    private let calendarName = "Meal Plan"

    // MARK: - Authorization

    /// Requests full calendar write access. Returns true if granted.
    func requestAccess() async -> Bool {
        if #available(iOS 17, *) {
            do {
                return try await store.requestWriteOnlyAccessToEvents()
            } catch {
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var isAuthorized: Bool {
        let status = authorizationStatus
        if #available(iOS 17, *) {
            return status == .fullAccess || status == .writeOnly
        } else {
            return status == .authorized
        }
    }

    // MARK: - Add / Remove Events

    /// Adds an all-day event for `mealName` on `date` to the Meal Plan calendar.
    /// Returns the event identifier so it can be stored for later removal.
    @discardableResult
    func addMeal(name mealName: String, on date: Date) throws -> String {
        let calendar = try findOrCreateCalendar()
        let event = EKEvent(eventStore: store)
        event.title = mealName
        event.isAllDay = true
        event.startDate = date
        event.endDate = date
        event.calendar = calendar
        event.notes = "Added by Portio"
        try store.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    /// Removes a previously added event by its identifier. Silently ignores missing events.
    func removeEvent(identifier: String) throws {
        if let event = store.event(withIdentifier: identifier) {
            try store.remove(event, span: .thisEvent)
        }
    }

    // MARK: - Private

    private func findOrCreateCalendar() throws -> EKCalendar {
        // Re-use an existing calendar with the same name if possible.
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarName }) {
            return existing
        }
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = calendarName
        // Use the default calendar source (iCloud or local).
        cal.source = bestSource()
        try store.saveCalendar(cal, commit: true)
        return cal
    }

    private func bestSource() -> EKSource {
        // Prefer iCloud so the calendar syncs across devices.
        if let icloud = store.sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
            return icloud
        }
        if let calDAV = store.sources.first(where: { $0.sourceType == .calDAV }) {
            return calDAV
        }
        // Fall back to the local source.
        return store.sources.first(where: { $0.sourceType == .local }) ?? store.sources[0]
    }
}
