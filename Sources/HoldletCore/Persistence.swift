import Foundation

public struct SnapshotStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> Snapshot {
        guard FileManager.default.fileExists(atPath: url.path) else { return Snapshot() }
        let data = try Data(contentsOf: url)
        let value = try JSONDecoder().decode(Snapshot.self, from: data)
        guard value.version == 1 else { throw StoreError.unsupportedVersion }
        return value
    }
    public func save(_ snapshot: Snapshot) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    public enum StoreError: Error { case unsupportedVersion }
}
