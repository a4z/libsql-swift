import Foundation
import XCTest

@testable import Libsql

/// Tests verifying that Connection can safely outlive the Database that created it.
/// This validates the claim that Rust's Arc keeps connection resources alive.
final class ConnectionLifetimeTests: XCTestCase {

    /// Test: Connection survives after Database is deallocated
    /// Claim: "Connections can safely outlive the Database handle that created them"
    func testConnectionOutlivesDatabase() throws {
        var conn: Connection!

        // Database goes out of scope here

        try autoreleasepool {
            let db = try Database(":memory:")
            conn = try db.connect()
            _ = try conn.execute("CREATE TABLE test (id INTEGER)")
        }  // Database handle freed here

        // Connection should still work after Database is freed
        _ = try conn.execute("INSERT INTO test VALUES (1)")
        let rows = try conn.query("SELECT * FROM test")
        let row = rows.next()

        XCTAssertNotNil(row, "Should be able to query after Database is freed")
        XCTAssertEqual(try row?.getInt(0), 1, "Data should be intact")
    }

    /// Test: Connection from function that only returns Connection
    /// Claim: "Connection can outlive Database (Safe due to Rust Arc)"
    func testConnectionFromFunction() throws {
        func getConnection() throws -> Connection {
            let db = try Database(":memory:")
            let conn = try db.connect()
            _ = try conn.execute("CREATE TABLE test (value INTEGER)")
            return conn  // Database freed when function returns
        }

        let conn = try getConnection()

        // Should work even though Database is gone
        _ = try conn.execute("INSERT INTO test VALUES (42)")
        let result = try conn.query("SELECT value FROM test").next()
        XCTAssertEqual(try result?.getInt(0), 42)
    }

    /// Test: Connection created in nested scope
    /// Claim: "Database in Nested Scope (Safe due to Rust Arc)"
    func testConnectionInNestedScope() throws {
        var conn: Connection!

        if true {  // Simulate conditional scope
            let db = try Database(":memory:")
            conn = try db.connect()
            _ = try conn.execute("CREATE TABLE test (value TEXT)")
        }  // Database deallocated here

        // Connection still works
        _ = try conn.execute("INSERT INTO test VALUES ('hello')")
        let row = try conn.query("SELECT * FROM test").next()
        XCTAssertEqual(try row?.getString(0), "hello")
    }

    /// Test: Multiple sequential operations after Database is freed
    /// Claim: Connection remains fully functional
    func testMultipleOperationsAfterDatabaseFreed() throws {
        var conn: Connection!

        try autoreleasepool {
            let db = try Database(":memory:")
            conn = try db.connect()
            _ = try conn.execute("CREATE TABLE users (id INTEGER, name TEXT)")
        }

        // All these should work
        _ = try conn.execute("INSERT INTO users VALUES (1, 'Alice')")
        _ = try conn.execute("INSERT INTO users VALUES (2, 'Bob')")
        _ = try conn.execute("INSERT INTO users VALUES (3, 'Charlie')")

        var count = 0
        for row in try conn.query("SELECT * FROM users") {
            count += 1
            XCTAssertNotNil(try? row.getInt(0))
            XCTAssertNotNil(try? row.getString(1))
        }

        XCTAssertEqual(count, 3, "Should retrieve all 3 rows")
    }

    /// Test: Transaction works after Database is freed
    /// Claim: All connection features work, including transactions
    func testTransactionAfterDatabaseFreed() throws {
        var conn: Connection!

        do {
            let db = try Database(":memory:")
            conn = try db.connect()
            _ = try conn.execute("CREATE TABLE test (id INTEGER)")
        }

        // Transaction should work
        do {
            let tx = try conn.transaction()
            defer { tx.commit() }
            _ = try tx.execute("INSERT INTO test VALUES (1)")
        }

        let row = try conn.query("SELECT * FROM test").next()
        XCTAssertEqual(try row?.getInt(0), 1)
    }

    /// Test: Prepared statement works after Database is freed
    /// Claim: All connection features remain functional
    func testPreparedStatementAfterDatabaseFreed() throws {
        var conn: Connection!

        try autoreleasepool {
            let db = try Database(":memory:")
            conn = try db.connect()
            _ = try conn.execute("CREATE TABLE test (value INTEGER)")
        }

        // Prepared statement should work
        let stmt = try conn.prepare("INSERT INTO test VALUES (?)")
        _ = try stmt.bind([42]).execute()

        let row = try conn.query("SELECT * FROM test").next()
        XCTAssertEqual(try row?.getInt(0), 42)
    }
}
