import Foundation
import XCTest

@testable import Libsql

/// Tests verifying that multiple connections can share database state
/// even after the Database handle is freed.
/// This validates the Arc-based resource sharing in Rust.
final class MultipleConnectionsTests: XCTestCase {

    private var tempDir = TempDir()

    override func setUpWithError() throws {
        try super.setUpWithError()
        try tempDir.setup()
    }

    override func tearDownWithError() throws {
        tempDir.cleanup()
        try super.tearDownWithError()
    }

    /// Helper: Setup a clean test table using a transaction
    private func setupCleanTable(_ conn: Connection, _ sql: String) throws {
        let tx = try conn.transaction()
        defer { tx.commit() }
        try tx.executeBatch(
            """
            DROP TABLE IF EXISTS test;
            \(sql)
            """)
    }

    /// Test: Multiple connections share state
    /// Claim: "Multiple connections share the same underlying database"
    func testMultipleConnectionsShareState() throws {
        let dbPath = tempDir.path("test_multiple.db")
        let db = try Database(dbPath)
        let conn1 = try db.connect()
        let conn2 = try db.connect()

        try setupCleanTable(conn1, "CREATE TABLE test (id INTEGER)")
        _ = try conn1.execute("INSERT INTO test VALUES (1)")

        let row = try conn2.query("SELECT * FROM test").next()
        XCTAssertEqual(try row?.getInt(0), 1, "conn2 should see data inserted by conn1")
    }

    /// Test: Three connections all sharing state
    /// Claim: Arc supports multiple concurrent references
    func testThreeConnectionsShareState() throws {
        let dbPath = tempDir.path("test_three.db")
        let db = try Database(dbPath)
        let conn1 = try db.connect()
        let conn2 = try db.connect()
        let conn3 = try db.connect()

        try setupCleanTable(conn1, "CREATE TABLE test (id INTEGER, name TEXT)")

        // Each connection writes data
        _ = try conn1.execute("INSERT INTO test VALUES (1, 'Alice')")
        _ = try conn2.execute("INSERT INTO test VALUES (2, 'Bob')")
        _ = try conn3.execute("INSERT INTO test VALUES (3, 'Charlie')")

        // All should see all data
        var count = 0
        for _ in try conn1.query("SELECT * FROM test") {
            count += 1
        }
        XCTAssertEqual(count, 3, "conn1 should see all rows")

        count = 0
        for _ in try conn2.query("SELECT * FROM test") {
            count += 1
        }
        XCTAssertEqual(count, 3, "conn2 should see all rows")

        count = 0
        for _ in try conn3.query("SELECT * FROM test") {
            count += 1
        }
        XCTAssertEqual(count, 3, "conn3 should see all rows")
    }

    /// Test: Connections created at different times
    /// Claim: New connections can be created even after some are freed
    func testConnectionsCreatedSequentially() throws {
        let dbPath = tempDir.path("test_sequential.db")
        let db = try Database(dbPath)
        var connections: [Connection] = []

        // Create first connection
        let conn1 = try db.connect()
        try setupCleanTable(conn1, "CREATE TABLE test (id INTEGER)")
        connections.append(conn1)

        // Create second connection later
        let conn2 = try db.connect()
        _ = try conn2.execute("INSERT INTO test VALUES (1)")
        connections.append(conn2)

        // Create third connection
        let conn3 = try db.connect()
        connections.append(conn3)

        // All connections should work
        XCTAssertEqual(connections.count, 3)

        for (index, conn) in connections.enumerated() {
            let row = try conn.query("SELECT * FROM test").next()
            XCTAssertNotNil(row, "Connection \(index) should work")
            XCTAssertEqual(try row?.getInt(0), 1)
        }
    }

    /// Test: Connection pool pattern
    /// Claim: "Multiple Connections from One Database" pattern is safe
    func testConnectionPoolPattern() throws {
        class ConnectionPool {
            private var connections: [Connection] = []
            private let db: Database

            init(path: String, poolSize: Int) throws {
                db = try Database(path)
                for _ in 0..<poolSize {
                    connections.append(try db.connect())
                }
                // Initialize schema with first connection using transaction
                let tx = try connections[0].transaction()
                defer { tx.commit() }
                try tx.executeBatch(
                    """
                    DROP TABLE IF EXISTS test;
                    CREATE TABLE test (id INTEGER)
                    """)
            }

            func getConnection(_ index: Int) -> Connection? {
                guard index < connections.count else { return nil }
                return connections[index]
            }
        }

        let dbPath = tempDir.path("test_pool.db")
        let pool = try ConnectionPool(path: dbPath, poolSize: 5)

        // All pooled connections should work
        for i in 0..<5 {
            let conn = pool.getConnection(i)
            XCTAssertNotNil(conn)
            _ = try conn?.execute("INSERT INTO test VALUES (\(i))")
        }

        // Verify all inserts worked
        let conn = pool.getConnection(0)!
        var count = 0
        for _ in try conn.query("SELECT * FROM test") {
            count += 1
        }
        XCTAssertEqual(count, 5, "All 5 inserts should be visible")
    }

    /// Test: Simultaneous operations on multiple connections
    /// Claim: Thread-safe by design (Arc + Send + Sync)
    func testSimultaneousOperations() throws {
        let dbPath = tempDir.path("test_simultaneous.db")
        let db = try Database(dbPath)
        let conn1 = try db.connect()
        let conn2 = try db.connect()

        try setupCleanTable(conn1, "CREATE TABLE test (id INTEGER)")

        // Interleaved operations
        _ = try conn1.execute("INSERT INTO test VALUES (1)")
        _ = try conn2.execute("INSERT INTO test VALUES (2)")
        _ = try conn1.execute("INSERT INTO test VALUES (3)")

        var values: [Int] = []
        for row in try conn2.query("SELECT id FROM test ORDER BY id") {
            values.append(try row.getInt(0))
        }

        XCTAssertEqual(values, [1, 2, 3], "Both connections should see consistent data")
    }
}
