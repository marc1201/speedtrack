import CryptoKit
import Foundation

/// The OpenStreetMap files on the phone. A tap in Settings downloads one, which is checked against
/// the size and SHA-256 in `CountryMaps.json` before the map uses it. A download that breaks off
/// keeps what it has, and the next tap asks the server only for the rest: the server charges every
/// byte it sends against a monthly budget. When that budget is spent the server pauses downloads,
/// and the app says until when, and offers no download before then.
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
    private var tasks: [String: URLSessionDownloadTask] = [:]

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
            } else if FileManager.default.fileExists(atPath: Self.resumeData(for: map).path) {
                states[map.name] = .failed(Self.brokeOffMessage)
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
        let resumeFile = Self.resumeData(for: map)
        let task = if let resumeData = try? Data(contentsOf: resumeFile) {
            session.downloadTask(withResumeData: resumeData)
        } else {
            session.downloadTask(with: map.url)
        }
        // The task holds the resume data now, and gives new data if it breaks off again.
        try? FileManager.default.removeItem(at: resumeFile)
        task.taskDescription = map.name
        tasks[map.name] = task
        states[map.name] = .downloading(fraction: 0)
        task.resume()
    }

    /// Stops a download and throws away what it has.
    func cancel(_ map: CountryMap) {
        tasks.removeValue(forKey: map.name)?.cancel()
        try? FileManager.default.removeItem(at: Self.resumeData(for: map))
        states[map.name] = .absent
    }

    func delete(_ map: CountryMap) {
        cancel(map)
        try? FileManager.default.removeItem(at: Self.file(for: map))
    }

    fileprivate func progressed(_ name: String, task: Int, written: Int64) {
        guard tasks[name]?.taskIdentifier == task,
              let map = CountryMap.all.first(where: { $0.name == name })
        else { return }
        states[name] = .downloading(fraction: min(Double(written) / Double(map.bytes), 1))
    }

    fileprivate func finished(_ name: String, task: Int, as state: State) {
        guard tasks[name]?.taskIdentifier == task else { return }
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

    fileprivate func brokeOff(_ name: String, task: Int, error: Error, resumeData: Data?) {
        guard tasks[name]?.taskIdentifier == task,
              let map = CountryMap.all.first(where: { $0.name == name })
        else { return }
        tasks[name] = nil
        if let resumeData {
            try? resumeData.write(to: Self.resumeData(for: map))
            states[name] = .failed(Self.brokeOffMessage)
        } else if (error as? URLError)?.networkUnavailableReason == .constrained {
            states[name] = .failed("Low Data Mode is on, so the map was not downloaded.")
        } else {
            states[name] = .failed("The download failed: \(error.localizedDescription)")
        }
    }

    private static let brokeOffMessage = "The download stopped. Download again to continue where it stopped."

    nonisolated static func file(for map: CountryMap) -> URL {
        directory.appending(path: map.name)
    }

    private nonisolated static func resumeData(for map: CountryMap) -> URL {
        directory.appending(path: map.name + ".resume")
    }

    /// Files of earlier lists, and a check that was cut short, would only take space.
    private func removeUnlisted() {
        let kept = Set(CountryMap.all.flatMap { [Self.file(for: $0), Self.resumeData(for: $0)].map(\.lastPathComponent) })
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !kept.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Runs on the session's queue, before the session deletes the downloaded file.
    fileprivate nonisolated static func accept(_ download: URL, for map: CountryMap, response: URLResponse?) -> State {
        let response = response as? HTTPURLResponse
        switch response?.statusCode ?? 0 {
        case 200, 206:
            break
        case 503:
            let until = CountryMap.resumption(retryAfter: response?.value(forHTTPHeaderField: "Retry-After"), now: .now)
            return until.map { State.paused(until: $0) } ?? .failed("The map server is busy. Try again later.")
        case 404:
            return .failed("This map is not on the map server yet.")
        default:
            return .failed("The map server answered \(response?.statusCode ?? 0).")
        }
        let destination = file(for: map)
        let checking = destination.appendingPathExtension("checking")
        do {
            try? FileManager.default.removeItem(at: checking)
            try FileManager.default.moveItem(at: download, to: checking)
            let size = try checking.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard size.map(Int64.init) == map.bytes, try sha256(of: checking) == map.sha256 else {
                try? FileManager.default.removeItem(at: checking)
                return .failed("The download was damaged. Download again.")
            }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: checking, to: destination)
            return .ready
        } catch {
            try? FileManager.default.removeItem(at: checking)
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

/// URLSession calls back on a queue of its own. This checks a finished file there, and hands every
/// outcome to the store on the main actor.
private final class Receiver: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    weak var store: CountryMapStore?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let name = downloadTask.taskDescription else { return }
        let task = downloadTask.taskIdentifier
        let store = self.store
        Task { @MainActor in
            store?.progressed(name, task: task, written: totalBytesWritten)
        }
    }

    /// The maps come from the map server alone. A redirect elsewhere ends the download, whose answer
    /// then fails the status check.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(request.url?.host() == CountryMap.server.host() ? request : nil)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let name = downloadTask.taskDescription,
              let map = CountryMap.all.first(where: { $0.name == name })
        else { return }
        let task = downloadTask.taskIdentifier
        let state = CountryMapStore.accept(location, for: map, response: downloadTask.response)
        let store = self.store
        Task { @MainActor in
            store?.finished(name, task: task, as: state)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let name = task.taskDescription else { return }
        let identifier = task.taskIdentifier
        let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        let store = self.store
        Task { @MainActor in
            store?.brokeOff(name, task: identifier, error: error, resumeData: resumeData)
        }
    }
}
