import CryptoKit
import Foundation

/// The OpenStreetMap files on the phone. A tap in Settings downloads one, which is checked against
/// the size and SHA-256 in `CountryMaps.json` before the map uses it. What arrives goes straight into
/// a partial file, so a download that breaks off, or an app that iOS ends meanwhile, keeps it: the
/// next tap asks the server only for the rest, since the server charges every byte it sends against
/// a monthly budget. When that budget is spent the server pauses downloads, and the app says until
/// when, and offers no download before then.
@MainActor
final class CountryMapStore: ObservableObject {
    enum State: Equatable {
        case absent
        case downloading(fraction: Double)
        case ready
        case failed(String)
        /// The map server takes no downloads until then.
        case paused(until: Date)
    }

    @Published private(set) var states: [String: State] = [:]

    private let session: URLSession
    private var tasks: [String: URLSessionDataTask] = [:]

    /// In Library, which the system does not clear, and outside the phone's backup, since every file
    /// can be downloaded again. The path has no spaces, which MapLibre would have to decode.
    nonisolated static let directory: URL = {
        var directory = URL.libraryDirectory.appending(path: "Maps", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
        return directory
    }()

    nonisolated static let stoppedMessage = "The download stopped. Download again to continue where it stopped."

    init() {
        let configuration = URLSessionConfiguration.default
        // Low Data Mode means no large downloads.
        configuration.allowsConstrainedNetworkAccess = false
        configuration.urlCache = nil
        let receiver = Receiver()
        session = URLSession(configuration: configuration, delegate: receiver, delegateQueue: nil)
        receiver.store = self
        removeUnlisted()
        for map in CountryMap.all {
            if FileManager.default.fileExists(atPath: Self.file(for: map).path) {
                states[map.name] = .ready
            } else if Self.partSize(of: map) > 0 {
                states[map.name] = .failed(Self.stoppedMessage)
            }
        }
    }

    func state(of map: CountryMap) -> State {
        states[map.name] ?? .absent
    }

    /// The files MapLibre can draw.
    var readyFiles: [URL] {
        CountryMap.all.filter { state(of: $0) == .ready }.map(Self.file(for:))
    }

    func download(_ map: CountryMap) {
        if case .paused = state(of: map) { return }
        guard tasks[map.name] == nil else { return }
        var request = URLRequest(url: map.url)
        let offset = Self.partSize(of: map)
        if offset > 0 {
            request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
        }
        let task = session.dataTask(with: request)
        task.taskDescription = map.name
        tasks[map.name] = task
        states[map.name] = .downloading(fraction: min(Double(offset) / Double(map.bytes), 1))
        task.resume()
    }

    /// Stops a download and throws away what it has.
    func cancel(_ map: CountryMap) {
        tasks.removeValue(forKey: map.name)?.cancel()
        try? FileManager.default.removeItem(at: Self.part(for: map))
        states[map.name] = .absent
    }

    func delete(_ map: CountryMap) {
        cancel(map)
        try? FileManager.default.removeItem(at: Self.file(for: map))
    }

    fileprivate func progressed(_ name: String, task: Int, fraction: Double) {
        guard tasks[name]?.taskIdentifier == task else { return }
        states[name] = .downloading(fraction: fraction)
    }

    fileprivate func finished(_ name: String, task: Int, as state: State) {
        guard tasks[name]?.taskIdentifier == task else {
            // Cancelled while the file was checked: a cancel keeps nothing.
            if state == .ready, let map = CountryMap.all.first(where: { $0.name == name }) {
                try? FileManager.default.removeItem(at: Self.file(for: map))
            }
            return
        }
        tasks[name] = nil
        states[name] = state
        if case .paused(let until) = state {
            Task {
                try? await Task.sleep(for: .seconds(max(until.timeIntervalSinceNow, 0)))
                if self.states[name] == state {
                    self.states[name] = .absent
                }
            }
        }
    }

    nonisolated static func file(for map: CountryMap) -> URL {
        directory.appending(path: map.name)
    }

    nonisolated static func part(for map: CountryMap) -> URL {
        directory.appending(path: map.name + ".part")
    }

    nonisolated static func partSize(of map: CountryMap) -> Int64 {
        let size = try? part(for: map).resourceValues(forKeys: [.fileSizeKey]).fileSize
        return Int64(size ?? 0)
    }

    /// Files of earlier lists would only take space.
    private func removeUnlisted() {
        let kept = Set(CountryMap.all.flatMap { [Self.file(for: $0), Self.part(for: $0)].map(\.lastPathComponent) })
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !kept.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Makes a whole partial file the map, once its size and SHA-256 match the list. Runs off the
    /// main actor, since hashing a large file takes seconds.
    nonisolated static func finish(_ map: CountryMap) -> State {
        let part = part(for: map)
        let size = partSize(of: map)
        guard size == map.bytes else {
            if size > map.bytes {
                try? FileManager.default.removeItem(at: part)
                return .failed("The download was damaged. Download again.")
            }
            return .failed(stoppedMessage)
        }
        do {
            guard try sha256(of: part) == map.sha256 else {
                try? FileManager.default.removeItem(at: part)
                return .failed("The download was damaged. Download again.")
            }
            let destination = file(for: map)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: part, to: destination)
            return .ready
        } catch {
            return .failed("The map could not be saved: \(error.localizedDescription)")
        }
    }

    private nonisolated static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        var done = false
        while !done {
            // Each block is released before the next, or a large file would fill the memory.
            try autoreleasepool {
                let block = try handle.read(upToCount: 1 << 20) ?? Data()
                hash.update(data: block)
                done = block.isEmpty
            }
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// URLSession calls back on a serial queue of its own. This writes what arrives to the partial file
/// there, and hands every outcome to the store on the main actor.
private final class Receiver: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    weak var store: CountryMapStore?

    private struct Transfer {
        let map: CountryMap
        let file: FileHandle
        var written: Int64
        var percent = -1
        var failure: String?
    }

    /// Both are touched only on the session's queue, where every call below runs.
    private var transfers: [Int: Transfer] = [:]
    /// Tasks whose outcome has been handed on, so that their end hands on nothing more.
    private var concluded: Set<Int> = []

    /// The maps come from the map server alone, which sends no redirects. A redirect ends the
    /// download, whose answer then fails the status check.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let name = dataTask.taskDescription,
              let map = CountryMap.all.first(where: { $0.name == name })
        else {
            completionHandler(.cancel)
            return
        }
        let task = dataTask.taskIdentifier
        let http = response as? HTTPURLResponse
        let part = CountryMapStore.part(for: map)
        let offset = CountryMapStore.partSize(of: map)
        let answer = map.answer(
            status: http?.statusCode ?? 0,
            contentRange: http?.value(forHTTPHeaderField: "Content-Range"),
            retryAfter: http?.value(forHTTPHeaderField: "Retry-After"),
            offset: offset,
            now: .now
        )
        func conclude(_ state: CountryMapStore.State) {
            concluded.insert(task)
            report(name, task: task, state)
            completionHandler(.cancel)
        }
        switch answer {
        case .append, .restart:
            do {
                if answer == .restart || offset == 0 {
                    FileManager.default.createFile(atPath: part.path, contents: nil)
                }
                let file = try FileHandle(forWritingTo: part)
                let written = try Int64(file.seekToEnd())
                transfers[task] = Transfer(map: map, file: file, written: written)
                completionHandler(.allow)
            } catch {
                conclude(.failed("The map could not be saved: \(error.localizedDescription)"))
            }
        case .complete:
            conclude(CountryMapStore.finish(map))
        case .paused(let until):
            conclude(.paused(until: until))
        case .refused(let message, let discardPart):
            if discardPart {
                try? FileManager.default.removeItem(at: part)
            }
            conclude(.failed(message))
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let task = dataTask.taskIdentifier
        guard var transfer = transfers[task], transfer.failure == nil else { return }
        do {
            // An answer longer than the file is wrong, and would only fill the phone.
            guard transfer.written + Int64(data.count) <= transfer.map.bytes else {
                transfer.failure = "The download was damaged. Download again."
                try? FileManager.default.removeItem(at: CountryMapStore.part(for: transfer.map))
                transfers[task] = transfer
                dataTask.cancel()
                return
            }
            try transfer.file.write(contentsOf: data)
            transfer.written += Int64(data.count)
        } catch {
            transfer.failure = "The map could not be saved: \(error.localizedDescription)"
            dataTask.cancel()
        }
        // Whole percents only, so the main actor is not called for every few kilobytes.
        let percent = Int(min(transfer.written * 100 / transfer.map.bytes, 100))
        if percent != transfer.percent, let name = dataTask.taskDescription {
            transfer.percent = percent
            let store = self.store
            Task { @MainActor in
                store?.progressed(name, task: task, fraction: Double(percent) / 100)
            }
        }
        transfers[task] = transfer
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let identifier = task.taskIdentifier
        let transfer = transfers.removeValue(forKey: identifier)
        try? transfer?.file.close()
        guard concluded.remove(identifier) == nil, let name = task.taskDescription else { return }
        let state: CountryMapStore.State
        if let failure = transfer?.failure {
            state = .failed(failure)
        } else if let error = error as? URLError {
            if error.networkUnavailableReason == .constrained {
                state = .failed("Low Data Mode is on, so the map was not downloaded.")
            } else if transfer != nil {
                state = .failed(CountryMapStore.stoppedMessage)
            } else {
                state = .failed("The download failed: \(error.localizedDescription)")
            }
        } else if let error {
            state = .failed("The download failed: \(error.localizedDescription)")
        } else if let transfer {
            state = CountryMapStore.finish(transfer.map)
        } else {
            state = .failed("The map server sent nothing.")
        }
        report(name, task: identifier, state)
    }

    private func report(_ name: String, task: Int, _ state: CountryMapStore.State) {
        let store = self.store
        Task { @MainActor in
            store?.finished(name, task: task, as: state)
        }
    }
}
