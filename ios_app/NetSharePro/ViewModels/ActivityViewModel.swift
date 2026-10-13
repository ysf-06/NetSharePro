import Foundation
import Combine

@MainActor
final class ActivityViewModel: ObservableObject {
    @Published private(set) var events: [ActivityEvent] = []
    @Published private(set) var blockedCount = 0
    @Published private(set) var isEmpty: Bool = true

    private let engine: ProxyEngine
    private var refreshTimer: AnyCancellable?

    init(engine: ProxyEngine) {
        self.engine = engine
        refreshTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func refresh() {
        events = engine.activityStore.snapshot()
        blockedCount = engine.activityStore.blockedCountSnapshot()
        isEmpty = events.isEmpty
    }

    func clearHistory() {
        engine.activityStore.clear()
        refresh()
    }
}
