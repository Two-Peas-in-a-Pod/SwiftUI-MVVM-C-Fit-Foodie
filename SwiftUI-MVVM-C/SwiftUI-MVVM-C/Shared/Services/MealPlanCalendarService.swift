//
//  MealPlanCalendarService.swift
//  SwiftUI-MVVM-C
//

import EventKit
import Foundation

/// Manages adding meal plan entries to the user's iOS Calendar.
@MainActor
final class MealPlanCalendarService: ObservableObject {
    static let shared = MealPlanCalendarService()

    private let store = EKEventStore()

    // MARK: - Authorization

    /// Requests calendar write access. Returns true if granted.
    func requestAccess() async -> Bool {
        if #available(iOS 17, *) {
            do {
                // Full access is required to enumerate calendars via store.calendars(for:)
                return try await store.requestFullAccessToEvents()
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
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    // MARK: - Calendar list

    /// Returns all writable event calendars, sorted by source title then calendar title.
    func availableCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted {
                let s = $0.source.title.localizedCompare($1.source.title)
                return s == .orderedSame ? $0.title < $1.title : s == .orderedAscending
            }
    }

    /// Returns the calendar matching a stored identifier, or nil if not found.
    func calendar(for identifier: String) -> EKCalendar? {
        guard !identifier.isEmpty else { return nil }
        return store.calendars(for: .event).first { $0.calendarIdentifier == identifier }
    }

    // MARK: - Add / Remove Events

    /// Adds an all-day event for `mealName` on `date` to the given calendar.
    /// Returns the event identifier so it can be stored for later removal.
    @discardableResult
    func addMeal(name mealName: String, on date: Date, to calendar: EKCalendar) throws -> String {
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
}
