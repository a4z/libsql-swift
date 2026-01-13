
#if !canImport(ObjectiveC)
@inlinable
public func autoreleasepool<Result>(_ body: () throws -> Result) rethrows -> Result {
    return try body()
}
#endif