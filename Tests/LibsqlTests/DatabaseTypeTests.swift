import Foundation
import XCTest

@testable import Libsql

/// Tests verifying behavior differences between database types.
/// This test suite demonstrates "parameterized" testing patterns in Swift XCTest.
final class DatabaseTypeTests: XCTestCase {

    // MARK: - Test Lifecycle

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

    override func tearDown() {
        super.tearDown()
        // Clean up any test database files
        try? FileManager.default.removeItem(atPath: "test_file_based.db")
        try? FileManager.default.removeItem(atPath: "test_file_based.db-shm")
        try? FileManager.default.removeItem(atPath: "test_file_based.db-wal")
    }

    // MARK: - Parameterized Test Helpers

    /// Database configuration for testing
    struct DatabaseConfig {
        let name: String
        let path: String
        let supportsMultipleConnections: Bool

        static let memory = DatabaseConfig(
            name: "memory",
            path: ":memory:",
            supportsMultipleConnections: false
        )

        static let file = DatabaseConfig(
            name: "file",
            path: "test_file_based.db",
            supportsMultipleConnections: true
        )

        static let allConfigs = [memory, file]
    }

    /// Helper method to run a test with multiple database configurations
    /// This is Swift's way of doing "parameterized" tests
    private func runTest(
        configs: [DatabaseConfig],
        test: (DatabaseConfig, Database) throws -> Void
    ) throws {
        for config in configs {
            let db = try Database(config.path)
            try test(config, db)
        }
    }

    // MARK: - Single Connection Tests (Work for all database types)

    /// Test: Single connection works for all database types
    func testSingleConnectionWorks() throws {
        try runTest(configs: DatabaseConfig.allConfigs) { config, db in
            let conn = try db.connect()
            try setupCleanTable(conn, "CREATE TABLE test (id INTEGER)")
            _ = try conn.execute("INSERT INTO test VALUES (42)")

            let row = try conn.query("SELECT * FROM test").next()
            XCTAssertEqual(
                try row?.getInt(0), 42,
                "Single connection should work for \(config.name) database"
            )
        }
    }

    /// Test: Connection outlives Database for all types
    func testConnectionOutlivesDatabaseForAllTypes() throws {
        // Test :memory: database
        do {
            var conn: Connection!
            // TODO: Should be autoreleasepool, but Linux doesn't support it - maybe implement cross-platform version later
            do {
                let db = try Database(":memory:")
                conn = try db.connect()
                _ = try conn.execute("CREATE TABLE test (id INTEGER)")
                _ = try conn.execute("INSERT INTO test VALUES (1)")
            }

            let row = try conn.query("SELECT * FROM test").next()
            XCTAssertEqual(
                try row?.getInt(0), 1, "Memory database connection should outlive Database")
        }

        // Test file-based database
        do {
            var conn: Connection!
            // TODO: Should be autoreleasepool, but Linux doesn't support it - maybe implement cross-platform version later
            do {
                let db = try Database("test_file_based.db")
                conn = try db.connect()
                try setupCleanTable(conn, "CREATE TABLE test (id INTEGER)")
                _ = try conn.execute("INSERT INTO test VALUES (2)")
            }

            let row = try conn.query("SELECT * FROM test").next()
            XCTAssertEqual(
                try row?.getInt(0), 2, "File database connection should outlive Database")
        }
    }

    // MARK: - Multiple Connection Tests (Database-type specific)

    /// Test: Memory databases are isolated per connection
    func testMemoryDatabaseIsolation() throws {
        let db = try Database(":memory:")
        let conn1 = try db.connect()
        let conn2 = try db.connect()

        // Create table and insert data with conn1
        _ = try conn1.execute("CREATE TABLE test (id INTEGER)")
        _ = try conn1.execute("INSERT INTO test VALUES (1)")

        // Verify conn1 can see its own data
        let row1 = try conn1.query("SELECT * FROM test").next()
        XCTAssertEqual(try row1?.getInt(0), 1, "conn1 should see its own data")

        // conn2 should NOT see conn1's table (isolated database)
        XCTAssertThrowsError(
            try conn2.query("SELECT * FROM test").next(),
            "Memory database connections are isolated - conn2 should not see conn1's tables"
        ) { error in
            XCTAssertTrue(
                "\(error)".contains("no such table"),
                "Should fail with 'no such table' error"
            )
        }
    }

    /// Test: File-based databases share state across connections
    func testFileDatabaseSharing() throws {
        let db = try Database("test_file_based.db")
        let conn1 = try db.connect()
        let conn2 = try db.connect()

        // Create table and insert data with conn1
        try setupCleanTable(conn1, "CREATE TABLE test (id INTEGER)")
        _ = try conn1.execute("INSERT INTO test VALUES (1)")

        // conn2 SHOULD see conn1's data (shared database)
        let row = try conn2.query("SELECT * FROM test").next()
        XCTAssertEqual(
            try row?.getInt(0), 1,
            "File-based database connections share state"
        )

        // Verify bidirectional sharing
        _ = try conn2.execute("INSERT INTO test VALUES (2)")
        var count = 0
        for _ in try conn1.query("SELECT * FROM test") {
            count += 1
        }
        XCTAssertEqual(count, 2, "Both connections should see both rows")
    }

    /// Test: Multiple connections behavior varies by database type
    func testMultipleConnectionsBehavior() throws {
        // This demonstrates how to write a test that has different expectations
        // based on database type (a common pattern in parameterized testing)

        for config in DatabaseConfig.allConfigs {
            let db = try Database(config.path)
            let conn1 = try db.connect()
            let conn2 = try db.connect()

            if config.path == ":memory:" {
                // Setup conn1's isolated database
                _ = try conn1.execute("CREATE TABLE test (id INTEGER)")
            } else {
                // Setup shared database using transaction
                try setupCleanTable(conn1, "CREATE TABLE test (id INTEGER)")
            }

            _ = try conn1.execute("INSERT INTO test VALUES (1)")

            if config.supportsMultipleConnections {
                // File-based: conn2 should see conn1's data
                let row = try conn2.query("SELECT * FROM test").next()
                XCTAssertEqual(
                    try row?.getInt(0), 1,
                    "\(config.name) database should share state across connections"
                )
            } else {
                // Memory: conn2 should NOT see conn1's data
                XCTAssertThrowsError(
                    try conn2.query("SELECT * FROM test").next(),
                    "\(config.name) database should isolate connections"
                )
            }
        }
    }

    // MARK: - Connection Pool Pattern Tests

    /// Test: Connection pooling works correctly for file-based databases
    func testConnectionPoolWithFileDatabase() throws {
        class ConnectionPool {
            private let db: Database
            private var connections: [Connection] = []

            init(path: String, poolSize: Int) throws {
                db = try Database(path)
                for _ in 0..<poolSize {
                    connections.append(try db.connect())
                }

                // Initialize schema using transaction
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

            var size: Int { connections.count }
        }

        let pool = try ConnectionPool(path: "test_file_based.db", poolSize: 5)

        // All connections should share state
        for i in 0..<5 {
            guard let conn = pool.getConnection(i) else {
                XCTFail("Failed to get connection \(i)")
                continue
            }
            _ = try conn.execute("INSERT INTO test VALUES (\(i))")
        }

        // Verify all inserts are visible from any connection
        guard let conn = pool.getConnection(0) else {
            XCTFail("Failed to get connection")
            return
        }

        var count = 0
        for _ in try conn.query("SELECT * FROM test") {
            count += 1
        }
        XCTAssertEqual(count, 5, "All 5 inserts should be visible from pooled connections")
    }

    /// Test: Connection pooling with :memory: requires understanding isolation
    func testConnectionPoolWithMemoryDatabase() throws {
        // This test documents that :memory: pooling doesn't work as expected
        let db = try Database(":memory:")
        let conn1 = try db.connect()
        let conn2 = try db.connect()

        // Each connection needs its own schema since they're isolated
        _ = try conn1.execute("CREATE TABLE test (id INTEGER)")
        _ = try conn1.execute("INSERT INTO test VALUES (1)")

        // conn2 has its own isolated database - needs its own schema
        _ = try conn2.execute("CREATE TABLE test (id INTEGER)")
        _ = try conn2.execute("INSERT INTO test VALUES (2)")

        // Each sees only its own data
        let row1 = try conn1.query("SELECT * FROM test").next()
        XCTAssertEqual(try row1?.getInt(0), 1, "conn1 sees only its own data")

        let row2 = try conn2.query("SELECT * FROM test").next()
        XCTAssertEqual(try row2?.getInt(0), 2, "conn2 sees only its own data")
    }

    // MARK: - Best Practices Demonstration

    /// Test: Recommended pattern - explicit database type choice
    func testRecommendedPatterns() throws {
        // PATTERN 1: Use :memory: for isolated testing
        func isolatedTest() throws {
            let db = try Database(":memory:")
            let conn = try db.connect()
            _ = try conn.execute("CREATE TABLE test (id INTEGER)")
            _ = try conn.execute("INSERT INTO test VALUES (1)")
            // Each test gets isolated database - no cleanup needed
        }

        try isolatedTest()

        // PATTERN 2: Use file database for shared state
        func sharedStateTest() throws {
            let db = try Database("test_file_based.db")
            let conn1 = try db.connect()
            let conn2 = try db.connect()

            // Setup clean table using transaction
            do {
                let tx = try conn1.transaction()
                defer { tx.commit() }
                try tx.executeBatch(
                    """
                    DROP TABLE IF EXISTS shared;
                    CREATE TABLE shared (id INTEGER);
                    INSERT INTO shared VALUES (1)
                    """)
            }

            // conn2 sees conn1's changes (after transaction committed)
            let row = try conn2.query("SELECT * FROM shared").next()
            XCTAssertNotNil(row)
        }

        try sharedStateTest()
    }
}
