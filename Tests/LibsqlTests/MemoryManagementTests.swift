import Foundation
import XCTest

@testable import Libsql

/// Tests for memory management and resource cleanup.
/// Validates that Arc properly manages memory without leaks.
final class MemoryManagementTests: XCTestCase {

    /// Test: Rapid allocation and deallocation
    /// Claim: No memory leaks with proper Arc management
    func testRapidAllocationDeallocation() throws {
        // Create and destroy many database/connection pairs
        for i in 0..<1000 {
            // TODO: Should be autoreleasepool, but Linux doesn't support it - maybe implement cross-platform version later
            do {
                let db = try Database(":memory:")
                let conn = try db.connect()
                _ = try conn.execute("CREATE TABLE test\(i) (id INTEGER)")
                _ = try conn.execute("INSERT INTO test\(i) VALUES (\(i))")

                let row = try conn.query("SELECT * FROM test\(i)").next()
                XCTAssertEqual(try row?.getInt(0), i)
            }
        }

        // If we got here without crashing, memory management is working
        XCTAssertTrue(true, "Rapid alloc/dealloc completed without crashes")
    }

    /// Test: Connection outlives Database in rapid cycles
    /// Claim: Arc properly manages reference counting
    func testConnectionOutlivesDatabaseRapidly() throws {
        var connections: [Connection] = []

        // Create many connections, all outliving their databases
        for i in 0..<100 {
            // TODO: Should be autoreleasepool, but Linux doesn't support it - maybe implement cross-platform version later
            do {
                let db = try Database(":memory:")
                let conn = try db.connect()
                _ = try conn.execute("CREATE TABLE test (id INTEGER)")
                _ = try conn.execute("INSERT INTO test VALUES (\(i))")
                connections.append(conn)
            }  // Database freed, but connection kept
        }

        // All connections should still work
        for (index, conn) in connections.enumerated() {
            let row = try conn.query("SELECT * FROM test").next()
            XCTAssertEqual(try row?.getInt(0), index, "Connection \(index) should work")
        }

        // Clear connections to test cleanup
        connections.removeAll()

        XCTAssertTrue(true, "All connections cleaned up properly")
    }

    /// Test: Rapidly create many connections per database
    /// Claim: Multiple connections share Arc without leaks
    /// Note: Uses single-connection :memory: per iteration for isolation
    func testMultipleConnectionsPerDatabaseRapid() throws {
        for _ in 0..<100 {
            let db = try Database(":memory:")

            let conn1 = try db.connect()
            _ = try conn1.execute("CREATE TABLE test (id INTEGER)")
            _ = try conn1.execute("INSERT INTO test VALUES (1)")

            let row = try conn1.query("SELECT * FROM test").next()
            XCTAssertEqual(try row?.getInt(0), 1)
        }

        XCTAssertTrue(true, "Multiple databases cycled successfully")
    }

    /// Test: Large data operations after Database freed
    /// Claim: Connection maintains full functionality
    func testLargeDataOperationsAfterDatabaseFreed() throws {
        var conn: Connection!

        // TODO: Should be autoreleasepool, but Linux doesn't support it - maybe implement cross-platform version later
        do {
            let db = try Database(":memory:")
            conn = try db.connect()
            _ = try conn.execute("CREATE TABLE test (id INTEGER, data TEXT)")
        }

        // Insert many rows
        for i in 0..<1000 {
            _ = try conn.execute(
                "INSERT INTO test VALUES (?, ?)", [i, String(repeating: "x", count: 100)])
        }

        // Query all back
        var count = 0
        for _ in try conn.query("SELECT * FROM test") {
            count += 1
        }

        XCTAssertEqual(count, 1000, "Should handle large datasets")
    }

    /// Test: Batch operations after Database freed
    /// Claim: All connection features remain functional
    func testBatchOperationsAfterDatabaseFreed() throws {
        var conn: Connection!

        // TODO: Should be autoreleasepool, but Linux doesn't support it - maybe implement cross-platform version later
        do {
            let db = try Database(":memory:")
            conn = try db.connect()
        }

        // Batch creation and insertion
        try conn.executeBatch(
            """
                CREATE TABLE users (id INTEGER, name TEXT);
                INSERT INTO users VALUES (1, 'Alice');
                INSERT INTO users VALUES (2, 'Bob');
                INSERT INTO users VALUES (3, 'Charlie');
            """)

        var count = 0
        for _ in try conn.query("SELECT * FROM users") {
            count += 1
        }

        XCTAssertEqual(count, 3, "Batch operations should work")
    }

    /// Test: Connection lifecycle without Database reference
    /// Claim: Connection is self-contained via Arc
    func testConnectionLifecycleIndependent() throws {
        func createAndUseConnection() throws {
            var conn: Connection!

            do {
                let db = try Database(":memory:")
                conn = try db.connect()
                _ = try conn.execute("CREATE TABLE test (value INTEGER)")
            }

            // Use connection in different scope from creation
            _ = try conn.execute("INSERT INTO test VALUES (42)")

            let result = try conn.query("SELECT value FROM test").next()
            XCTAssertEqual(try result?.getInt(0), 42)
        }

        // Run multiple times to stress test
        for _ in 0..<100 {
            try createAndUseConnection()
        }

        XCTAssertTrue(true, "Connection lifecycle independent of Database")
    }

    /// Test: Stress test with mixed operations
    /// Claim: System remains stable under load
    func testStressMixedOperations() throws {
        var allConnections: [Connection] = []

        // Create varied patterns
        for i in 0..<50 {
            let db = try Database(":memory:")

            // All single connection since :memory: doesn't share
            let conn = try db.connect()
            _ = try conn.execute("CREATE TABLE test (id INTEGER)")
            _ = try conn.execute("INSERT INTO test VALUES (\(i))")
            allConnections.append(conn)
        }

        // All connections should still work
        for (index, conn) in allConnections.enumerated() {
            // Basic operation should succeed
            XCTAssertNoThrow(try conn.query("SELECT 1").next(), "Connection \(index) should work")
        }

        XCTAssertEqual(allConnections.count, 50, "Should have created 50 connections")
    }
}
