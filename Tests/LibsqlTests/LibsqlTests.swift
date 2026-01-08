import Foundation
import XCTest

@testable import Libsql

final class LibsqlTests: XCTestCase {
    func testOpenDbMemory() throws {
        let db = try Database(":memory:")
        let _ = try db.connect()
    }

    func testOpenDbFile() throws {
        let db = try Database("test.db")
        let _ = try db.connect()
    }

    func testExecute() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        _ = try conn.execute("create table test (i integer, s text)")
        _ = try conn.execute("insert into test values (?, ?)", [1, "lorem ipsum"])
        let row = try conn.query("select * from test").next()!

        XCTAssertEqual(try row.getInt(0), 1)
        XCTAssertEqual(try row.getString(1), "lorem ipsum")
    }

    func testExecuteBatch() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        _ = try conn.executeBatch(
            """
                create table test (i integer, s text);
                insert into test values (1, 'lorem ipsum');
            """)
        let row = try conn.query("select * from test").next()!

        XCTAssertEqual(try row.getInt(0), 1)
        XCTAssertEqual(try row.getString(1), "lorem ipsum")
    }

    func testQuerySimple() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()

        XCTAssertEqual(try conn.query("select 1").next()!.getInt(0), 1)
        XCTAssertEqual(try conn.query("select :named", [":named": 1]).next()!.getInt(0), 1)
        XCTAssertEqual(try conn.query("select ?", [1]).next()!.getInt(0), 1)
    }

    func testStatement() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        let stmt = try conn.prepare("select ?").bind([1])
        XCTAssertEqual(try stmt.query().next()!.getInt(0), 1)
    }

    func testStatementWithNamedParams() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()

        // Test with single named parameter
        let stmt1 = try conn.prepare("select :value").bind([":value": 42])
        XCTAssertEqual(try stmt1.query().next()!.getInt(0), 42)

        // Test with multiple named parameters
        let stmt2 = try conn.prepare("select :a + :b").bind([":a": 10, ":b": 32])
        XCTAssertEqual(try stmt2.query().next()!.getInt(0), 42)

        // Test with different types
        let stmt3 = try conn.prepare("select :name, :age, :score")
            //.bind([":name": "Alice", ":age": 25, ":score": 95.5])
            .bind([":age": 25, ":name": "Alice", ":score": 95.5])  // play with parameter order
        let row = try stmt3.query().next()!
        XCTAssertEqual(try row.getString(0), "Alice")
        XCTAssertEqual(try row.getInt(1), 25)
        XCTAssertEqual(try row.getDouble(2), 95.5)
    }

    func testTransaction() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()

        do {
            let tx = try conn.transaction()
            defer { tx.commit() }

            _ = try tx.execute("create table test (i integer)")
            _ = try tx.execute("insert into test values (:v)", [":v": 1])
        }

        XCTAssertEqual(try conn.query("select * from test").next()!.getInt(0), 1)
    }

    func testTransactionRollback() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()

        _ = try conn.execute("create table test (i integer)")

        do {
            let tx = try conn.transaction()
            defer { tx.rollback() }

            _ = try tx.execute("insert into test values (:v)", [":v": 1])
        }

        XCTAssert(try conn.query("select * from test").next() == nil)
    }

    func testQueryMultiple() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()

        _ = try conn.execute("create table test (i integer, t text, r real, b blob)")

        let range = 0...255

        for i in range {
            _ = try conn.execute(
                "insert into test values (?, ?, ?, ?)",
                [i, "\(i)", exp(Double(i)), Data([UInt8(i)])]
            )
        }

        for (i, row) in zip(range, try conn.query("select * from test")) {
            XCTAssertEqual(try row.getInt(0), i)
            XCTAssertEqual(try row.getString(1), "\(i)")
            XCTAssertEqual(try row.getDouble(2), exp(Double(i)))
            XCTAssertEqual(try row.getData(3), Data([UInt8(i)]))
        }
    }

    func testColumnCountAndNames() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()

        _ = try conn.execute("create table test (id integer, name text, value real)")
        _ = try conn.execute("insert into test values (1, 'test', 3.14)")

        let rows = try conn.query("select * from test")

        XCTAssertEqual(rows.columnCount(), 3)
        XCTAssertEqual(try rows.columnName(0), "id")
        XCTAssertEqual(try rows.columnName(1), "name")
        XCTAssertEqual(try rows.columnName(2), "value")
    }

    func testColumnNameOutOfRange() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()

        _ = try conn.execute("create table test (id integer)")
        _ = try conn.execute("insert into test values (1)")

        let rows = try conn.query("select * from test")

        XCTAssertThrowsError(try rows.columnName(-1)) { error in
            XCTAssert(error is LibsqlError)
            if case LibsqlError.indexOutOfRange = error {
            } else {
                XCTFail("Expected indexOutOfRange error")
            }
        }

        XCTAssertNoThrow(try rows.columnName(0))

        XCTAssertThrowsError(try rows.columnName(1)) { error in
            XCTAssert(error is LibsqlError)
            if case LibsqlError.indexOutOfRange = error {
            } else {
                XCTFail("Expected indexOutOfRange error")
            }
        }
    }
}
