import Combine
import Foundation
import Network

/// Whether the phone is offline, for the map. It only watches the network path and sends nothing.
/// A change counts only once it lasts, so a short tunnel does not zoom the map out and back: a lost
/// path counts after a few seconds, and a path that is back only after it has held for longer. A
/// path can exist and still carry no data, as with a weak signal at speed, and this cannot tell.
final class Connectivity: ObservableObject {
    static let offlineAfter: TimeInterval = 5
    static let onlineAfter: TimeInterval = 30

    @Published private(set) var isOffline = false

    private let monitor = NWPathMonitor()
    private var hasPath = false
    private var pending: DispatchWorkItem?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isOffline = path.status != .satisfied
            DispatchQueue.main.async {
                self?.settle(isOffline: isOffline)
            }
        }
        monitor.start(queue: DispatchQueue(label: "Connectivity"))
    }

    deinit {
        monitor.cancel()
        pending?.cancel()
    }

    /// Runs on the main queue. The first path counts at once, and a later change once it lasts.
    private func settle(isOffline: Bool) {
        pending?.cancel()
        pending = nil
        guard hasPath else {
            hasPath = true
            self.isOffline = isOffline
            return
        }
        guard isOffline != self.isOffline else { return }
        let change = DispatchWorkItem { [weak self] in
            self?.isOffline = isOffline
        }
        pending = change
        let delay = isOffline ? Self.offlineAfter : Self.onlineAfter
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: change)
    }
}
