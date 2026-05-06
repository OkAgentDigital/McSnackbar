// AppleMCPService.swift
// Snackbar
//
// Native Swift wrapper for Apple platform APIs (Contacts, Calendar, Reminders, Notes, Mail).
// Provides MCP-compatible tool implementations that replace the supermemoryai/apple-mcp
// JXA/AppleScript approach with native framework calls.
//
// Frameworks used:
//   - Contacts (CNContactStore)
//   - EventKit (EKEventStore for Calendar & Reminders)
//   - Accounts (ACAccountStore for Mail)
//
// Created by DevStudio Integration

import Foundation
import Contacts
import EventKit
import Accounts

/// Native Apple platform API service for MCP tool integration.
/// Replaces the supermemoryai/apple-mcp JXA-based approach with native Swift.
public class AppleMCPService: ObservableObject {
    public static let shared = AppleMCPService()

    // MARK: - Published State

    @Published public private(set) var contactsAuthorized: Bool = false
    @Published public private(set) var calendarAuthorized: Bool = false
    @Published public private(set) var remindersAuthorized: Bool = false
    @Published public private(set) var notesAuthorized: Bool = false

    // MARK: - Stores

    private let contactStore = CNContactStore()
    private let eventStore = EKEventStore()

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Check authorization status for all Apple platform APIs.
    public func checkAuthorizationStatus() {
        contactsAuthorized = CNContactStore.authorizationStatus(for: .contacts) == .authorized
        calendarAuthorized = EKEventStore.authorizationStatus(for: .event) == .authorized
        remindersAuthorized = EKEventStore.authorizationStatus(for: .reminder) == .authorized
        // Notes uses EKEventStore for now (Notes are accessed via AppleScript fallback)
        notesAuthorized = false
    }

    /// Request authorization for all Apple platform APIs.
    public func requestAllAuthorizations() async {
        await requestContactsAccess()
        await requestCalendarAccess()
        await requestRemindersAccess()
    }

    public func requestContactsAccess() async {
        do {
            try await contactStore.requestAccess(for: .contacts)
            contactsAuthorized = true
        } catch {
            print("⚠️ Contacts access denied: \(error.localizedDescription)")
        }
    }

    public func requestCalendarAccess() async {
        do {
            try await eventStore.requestAccess(to: .event)
            calendarAuthorized = true
        } catch {
            print("⚠️ Calendar access denied: \(error.localizedDescription)")
        }
    }

    public func requestRemindersAccess() async {
        do {
            try await eventStore.requestAccess(to: .reminder)
            remindersAuthorized = true
        } catch {
            print("⚠️ Reminders access denied: \(error.localizedDescription)")
        }
    }

    // MARK: - Contacts Tools

    /// Search contacts by name, email, or phone.
    /// - Parameter query: Search string.
    /// - Returns: Array of contact dictionaries.
    public func searchContacts(query: String) -> [[String: Any]] {
        guard contactsAuthorized else { return [] }

        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactIdentifierKey
        ] as [CNKeyDescriptor]

        let predicate = CNContact.predicateForContacts(matchingName: query)
        do {
            let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keys)
            return contacts.map { contact in
                [
                    "id": contact.identifier,
                    "givenName": contact.givenName,
                    "familyName": contact.familyName,
                    "emails": contact.emailAddresses.map { String($0.value) },
                    "phones": contact.phoneNumbers.map { $0.value.stringValue }
                ]
            }
        } catch {
            print("⚠️ Contact search failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Get a contact by identifier.
    /// - Parameter id: Contact identifier.
    /// - Returns: Contact dictionary or nil.
    public func getContact(id: String) -> [String: Any]? {
        guard contactsAuthorized else { return nil }

        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactIdentifierKey,
            CNContactOrganizationNameKey,
            CNContactDepartmentNameKey,
            CNContactJobTitleKey
        ] as [CNKeyDescriptor]

        do {
            let contact = try contactStore.unifiedContact(withIdentifier: id, keysToFetch: keys)
            return [
                "id": contact.identifier,
                "givenName": contact.givenName,
                "familyName": contact.familyName,
                "organization": contact.organizationName,
                "department": contact.departmentName,
                "jobTitle": contact.jobTitle,
                "emails": contact.emailAddresses.map { String($0.value) },
                "phones": contact.phoneNumbers.map { $0.value.stringValue }
            ]
        } catch {
            print("⚠️ Contact fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Calendar Tools

    /// Fetch calendar events for a date range.
    /// - Parameters:
    ///   - startDate: Start of range.
    ///   - endDate: End of range.
    ///   - calendarName: Optional calendar name filter.
    /// - Returns: Array of event dictionaries.
    public func fetchCalendarEvents(startDate: Date, endDate: Date, calendarName: String? = nil) -> [[String: Any]] {
        guard calendarAuthorized else { return [] }

        let calendars: [EKCalendar]
        if let name = calendarName {
            calendars = eventStore.calendars(for: .event).filter { $0.title == name }
        } else {
            calendars = eventStore.calendars(for: .event)
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars.isEmpty ? nil : calendars)
        let events = eventStore.events(matching: predicate)

        return events.map { event in
            [
                "id": event.eventIdentifier ?? "",
                "title": event.title ?? "",
                "startDate": event.startDate?.ISO8601Format() ?? "",
                "endDate": event.endDate?.ISO8601Format() ?? "",
                "location": event.location ?? "",
                "notes": event.notes ?? "",
                "calendar": event.calendar.title,
                "isAllDay": event.isAllDay
            ]
        }
    }

    /// Create a calendar event.
    /// - Parameters:
    ///   - title: Event title.
    ///   - startDate: Start date.
    ///   - endDate: End date.
    ///   - calendarName: Optional calendar name.
    ///   - notes: Optional notes.
    ///   - location: Optional location.
    /// - Returns: Event identifier or nil.
    @discardableResult
    public func createCalendarEvent(title: String, startDate: Date, endDate: Date, calendarName: String? = nil, notes: String? = nil, location: String? = nil) -> String? {
        guard calendarAuthorized else { return nil }

        guard let calendar = {
            if let name = calendarName, let cal = eventStore.calendars(for: .event).first(where: { $0.title == name }) {
                return cal
            }
            return eventStore.defaultCalendarForNewEvents ?? eventStore.calendars(for: .event).first
        }() else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        event.notes = notes
        event.location = location

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("⚠️ Event creation failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Reminders Tools

    /// Fetch reminders, optionally filtered by list name.
    /// - Parameter listName: Optional reminder list name filter.
    /// - Returns: Array of reminder dictionaries.
    public func fetchReminders(listName: String? = nil) -> [[String: Any]] {
        guard remindersAuthorized else { return [] }

        let calendars: [EKCalendar]
        if let name = listName {
            calendars = eventStore.calendars(for: .reminder).filter { $0.title == name }
        } else {
            calendars = eventStore.calendars(for: .reminder)
        }

        let predicate = eventStore.predicateForReminders(in: calendars.isEmpty ? nil : calendars)

        var result: [[String: Any]] = []
        let semaphore = DispatchSemaphore(value: 0)

        eventStore.fetchReminders(matching: predicate) { reminders in
            result = (reminders ?? []).map { reminder in
                [
                    "id": reminder.calendarItemIdentifier,
                    "title": reminder.title ?? "",
                    "notes": reminder.notes ?? "",
                    "dueDate": reminder.dueDateComponents?.date?.ISO8601Format() ?? "",
                    "completed": reminder.isCompleted,
                    "completionDate": reminder.completionDate?.ISO8601Format() ?? "",
                    "list": reminder.calendar.title,
                    "priority": reminder.priority
                ]
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 10.0)
        return result
    }

    /// Create a reminder.
    /// - Parameters:
    ///   - title: Reminder title.
    ///   - notes: Optional notes.
    ///   - dueDate: Optional due date.
    ///   - listName: Optional list name.
    /// - Returns: Reminder identifier or nil.
    @discardableResult
    public func createReminder(title: String, notes: String? = nil, dueDate: Date? = nil, listName: String? = nil) -> String? {
        guard remindersAuthorized else { return nil }

        guard let calendar = {
            if let name = listName, let cal = eventStore.calendars(for: .reminder).first(where: { $0.title == name }) {
                return cal
            }
            return eventStore.defaultCalendarForNewReminders() ?? eventStore.calendars(for: .reminder).first
        }() else { return nil }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = calendar

        if let due = dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
            reminder.dueDateComponents = components
        }

        do {
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            print("⚠️ Reminder creation failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Notes Tools

    /// Search notes using AppleScript (Notes app doesn't have a native Swift API).
    /// - Parameter query: Search string.
    /// - Returns: Array of note dictionaries.
    public func searchNotes(query: String) -> [[String: Any]] {
        let escapedQuery = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let script = """
        tell application "Notes"
            set matchingNotes to {}
            set allNotes to every note
            repeat with aNote in allNotes
                set noteName to name of aNote
                set noteBody to body of aNote
                if noteName contains "\(escapedQuery)" or noteBody contains "\(escapedQuery)" then
                    set end of matchingNotes to {name:noteName, id:id of aNote, body:noteBody}
                end if
            end repeat
            return matchingNotes
        end tell
        """

        return runAppleScript(script)
    }

    /// Create a note in the default folder.
    /// - Parameters:
    ///   - title: Note title.
    ///   - body: Note body text.
    ///   - folderName: Optional folder name.
    /// - Returns: True if successful.
    @discardableResult
    public func createNote(title: String, body: String, folderName: String? = nil) -> Bool {
        let escapedTitle = title
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script: String
        if let folder = folderName {
            let escapedFolder = folder
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            script = """
            tell application "Notes"
                set targetFolder to folder "\(escapedFolder)"
                make new note at targetFolder with properties {name:"\(escapedTitle)", body:"\(escapedBody)"}
            end tell
            """
        } else {
            script = """
            tell application "Notes"
                make new note with properties {name:"\(escapedTitle)", body:"\(escapedBody)"}
            end tell
            """
        }

        return runAppleScriptBool(script)
    }

    // MARK: - Mail Tools

    /// Search mail messages.
    /// - Parameter query: Search string.
    /// - Returns: Array of message dictionaries.
    public func searchMail(query: String) -> [[String: Any]] {
        let escapedQuery = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let script = """
        tell application "Mail"
            set matchingMessages to {}
            set allMessages to every message of inbox
            repeat with aMsg in allMessages
                set msgSubject to subject of aMsg
                set msgContent to content of aMsg
                if msgSubject contains "\(escapedQuery)" or msgContent contains "\(escapedQuery)" then
                    set end of matchingMessages to {subject:msgSubject, id:id of aMsg, sender:sender of aMsg, date:date received of aMsg}
                end if
            end repeat
            return matchingMessages
        end tell
        """

        return runAppleScript(script)
    }

    // MARK: - AppleScript Helpers

    /// Run an AppleScript that returns a list of records.
    /// Parses the result as a list of AppleEvent descriptors, extracting string values.
    private func runAppleScript(_ script: String) -> [[String: Any]] {
        var result: [[String: Any]] = []

        guard let scriptObject = NSAppleScript(source: script) else { return result }

        var error: NSDictionary?
        let output = scriptObject.executeAndReturnError(&error)

        if let error = error {
            print("⚠️ AppleScript error: \(error)")
            return result
        }

        // Parse the result as a list of descriptors
        for i in 0..<output.numberOfItems {
            if let descriptor = output.atIndex(i + 1) {
                var dict: [String: Any] = [:]
                // Extract string value as the primary content
                if let str = descriptor.stringValue {
                    dict["value"] = str
                }
                // If it's a list, extract sub-items
                if descriptor.numberOfItems > 0 {
                    var items: [String] = []
                    for j in 0..<descriptor.numberOfItems {
                        if let item = descriptor.atIndex(j + 1)?.stringValue {
                            items.append(item)
                        }
                    }
                    if !items.isEmpty {
                        dict["items"] = items
                    }
                }
                if !dict.isEmpty {
                    result.append(dict)
                }
            }
        }

        return result
    }

    /// Run an AppleScript that returns a boolean.
    private func runAppleScriptBool(_ script: String) -> Bool {
        guard let scriptObject = NSAppleScript(source: script) else { return false }

        var error: NSDictionary?
        let output = scriptObject.executeAndReturnError(&error)

        if let error = error {
            print("⚠️ AppleScript error: \(error)")
            return false
        }

        return output.booleanValue
    }
}
