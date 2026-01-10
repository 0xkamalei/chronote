import Foundation
import SwiftData
import SwiftUI

@Observable
class EventManager {
    var currentEvent: Event?
    private var modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        if let context = modelContext {
            fetchCurrentEvent(context: context)
        }
        
        NotificationCenter.default.addObserver(forName: .userDidBecomeIdle, object: nil, queue: .main) { [weak self] notification in
            self?.handleIdle(notification)
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchCurrentEvent(context: context)
    }
    
    private func fetchCurrentEvent(context: ModelContext) {
        // Find event with nil endTime
        // Note: Predicates in SwiftData can be tricky.
        // We use a simple predicate to find events where endTime is nil.
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { $0.endTime == nil },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            let events = try context.fetch(descriptor)
            self.currentEvent = events.first
        } catch {
            print("Failed to fetch current event: \(error)")
        }
    }
    
    func startEvent(name: String, startTime: Date = Date(), projectId: String? = nil) {
        guard let context = modelContext else { return }
        
        // Stop existing if any
        if currentEvent != nil {
            stopCurrentEvent()
        }
        
        let newEvent = Event(name: name, startTime: startTime, projectId: projectId)
        context.insert(newEvent)
        self.currentEvent = newEvent
        
        try? context.save()
    }
    
    func insertEvent(_ event: Event) {
         guard let context = modelContext else { return }
         context.insert(event)
         try? context.save()
    }
    
    func stopCurrentEvent(at date: Date = Date()) {
        guard let event = currentEvent else { return }
        
        event.endTime = max(event.startTime, date)
        self.currentEvent = nil
        
        try? modelContext?.save()
    }
    
    func updateEvent(_ event: Event) {
        try? modelContext?.save()
    }
    
    func getRecentEventNames(limit: Int = 5) -> [String] {
         guard let context = modelContext else { return [] }
         
         var descriptor = FetchDescriptor<Event>(
             sortBy: [SortDescriptor(\.startTime, order: .reverse)]
         )
         descriptor.fetchLimit = limit * 10
         
         do {
             let events = try context.fetch(descriptor)
             var names: [String] = []
             var seen: Set<String> = []
             
             for event in events {
                 let name = event.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                 if !name.isEmpty && !seen.contains(name) {
                     names.append(name)
                     seen.insert(name)
                     if names.count >= limit { break }
                 }
             }
             return names
         } catch {
             return []
         }
     }

    private func handleIdle(_ notification: Notification) {
        let stopOnIdle = UserDefaults.standard.bool(forKey: "stopEventOnIdle")
        if stopOnIdle, let idleStart = notification.userInfo?["idleStartTime"] as? Date {
            stopCurrentEvent(at: idleStart)
        }
    }
}
