import Foundation


#if !canImport(ObjectiveC)
@inlinable
public func autoreleasepool<Result>(_ body: () throws -> Result) rethrows -> Result {
    return try body()
}
#endif


struct TempDir: ~Copyable {
    private var url: URL?

    mutating func setup() throws {
        precondition(url == nil, "TempDir already set up")
        let baseDir = FileManager.default.temporaryDirectory
        let url = baseDir.appendingPathComponent("libsql-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        self.url = url
    }

    mutating func cleanup() {
        precondition(url != nil, "TempDir is not set up")
        try? FileManager.default.removeItem(at: url!)
        self.url = nil
        
    }

    @inlinable
    func path(_ name: String) -> String {
        precondition(url != nil, "TempDir is not set up")
        return url!.appendingPathComponent(name).path
    }
}
