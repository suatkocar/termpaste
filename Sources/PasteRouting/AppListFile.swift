import Foundation

/// apps.json on disk. A missing file is written with the defaults; an edited file is read again
/// when it changes; a file that cannot be read keeps the last list that could, and is only
/// replaced by a later save, which first keeps a copy of it next to the file.
public final class AppListFile {
    public let url: URL
    public private(set) var list: AppList
    /// Why the file on disk is not the list in use, or nil when it is.
    public private(set) var problem: String?
    private let defaults: () -> AppList
    private var stamp: Stamp?

    private struct Stamp: Equatable {
        var modified: Date?
        var size: Int?
    }

    public init(url: URL, defaults: @escaping () -> AppList) {
        self.url = url
        self.defaults = defaults
        list = defaults()
    }

    /// The copy kept when a save replaces a file that could not be read.
    public var unreadableCopyURL: URL {
        url.deletingLastPathComponent().appendingPathComponent("apps-unreadable.json")
    }

    /// Reads the file if it changed since the last read or write. Returns whether `list` or `problem` changed.
    @discardableResult
    public func refresh() -> Bool {
        guard let current = currentStamp() else {
            let before = (list, problem)
            do {
                try write(defaults())
            } catch {
                problem = "apps.json can’t be created: \(error.localizedDescription)"
                stamp = nil
            }
            return before != (list, problem)
        }
        guard current != stamp else { return false }
        stamp = current
        let before = (list, problem)
        do {
            list = try AppList.decode(Data(contentsOf: url))
            problem = nil
        } catch {
            problem = "apps.json can’t be read: \(Self.reason(error))"
        }
        return before != (list, problem)
    }

    public func save(_ newList: AppList) throws {
        if problem != nil, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: unreadableCopyURL)
            try FileManager.default.copyItem(at: url, to: unreadableCopyURL)
        }
        try write(newList)
    }

    private func write(_ newList: AppList) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try newList.encoded().write(to: url, options: .atomic)
        list = newList
        problem = nil
        stamp = currentStamp()
    }

    private func currentStamp() -> Stamp? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return Stamp(modified: attributes[.modificationDate] as? Date, size: (attributes[.size] as? NSNumber)?.intValue)
    }

    /// A short reason for the menu, naming the field where JSON decoding stopped.
    static func reason(_ error: Error) -> String {
        if let problem = error as? AppList.Problem { return problem.description }
        guard let error = error as? DecodingError else { return error.localizedDescription }
        func field(_ path: [CodingKey]) -> String {
            path.last(where: { $0.intValue == nil }).map { "“\($0.stringValue)”" } ?? "a value"
        }
        switch error {
        case .dataCorrupted(let context):
            return context.codingPath.isEmpty ? "it isn’t valid JSON" : "\(field(context.codingPath)) has an unknown value"
        case .keyNotFound(let key, _):
            return "“\(key.stringValue)” is missing"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "\(field(context.codingPath)) has the wrong type"
        @unknown default:
            return "it isn’t valid JSON"
        }
    }
}
