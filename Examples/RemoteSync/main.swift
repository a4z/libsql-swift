import Libsql
import Foundation

guard let tursoUrl = ProcessInfo.processInfo.environment["TURSO_DATABASE_URL"],
      !tursoUrl.isEmpty else {
    fatalError("TURSO_DATABASE_URL environment variable is required")
}

guard let tursoAuthToken = ProcessInfo.processInfo.environment["TURSO_AUTH_TOKEN"],
      !tursoAuthToken.isEmpty else {
    fatalError("TURSO_AUTH_TOKEN environment variable is required")
}

// Always start fresh - delete local db
let localDbPath = "./local.db"
// try? FileManager.default.removeItem(atPath: localDbPath)

let db = try Database(
    path: localDbPath,
    url: tursoUrl,
    authToken: tursoAuthToken,
    syncInterval: 1000
)

// Use a unique identifier so we know exactly what we're reading
let uniqueId = Int(Date().timeIntervalSince1970)
let testEmail = "test-\(uniqueId)@example.com"

print("Test ID: \(uniqueId)")
print("Test email: \(testEmail)")
print()

// --- Cleanup phase (use separate connection) ---
let cleanupConn = try db.connect()
_ = try cleanupConn.execute("DROP TABLE IF EXISTS users", [])
//try db.sync()

// Fresh connection for the actual test
let conn = try db.connect()

// Verify clean
do {
    _ = try conn.query("SELECT * FROM users", [])
    print("FAIL: Table still exists after drop+sync")
    exit(1)
} catch {
    print("OK: Table does not exist")
}

// Toggle: true = use executeBatch (BROKEN), false = use execute (WORKS)
let useBatch = true

if useBatch {
    // Create and insert with unique value using executeBatch
    _ = try conn.executeBatch("""
        CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT);
        INSERT INTO users VALUES (\(uniqueId), '\(testEmail)');
    """)
    print("Inserted row with id=\(uniqueId) (using executeBatch)")
} else {
    // Create and insert with unique value using individual execute calls
    _ = try conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)", [])
    _ = try conn.execute("INSERT INTO users VALUES (\(uniqueId), '\(testEmail)')", [])
    print("Inserted row with id=\(uniqueId) (using execute)")
}

// Read immediately - NO sync - this tests readYourWrites
print("\nReading immediately on SAME connection (no sync):")
var foundOnSameConn = false
do {
    for row in try conn.query("SELECT id, email FROM users WHERE id = \(uniqueId)", []) {
        let id = try row.getInt(0)
        let email = try row.getString(1)
        print("  Found: id=\(id), email=\(email)")
        if id == uniqueId && email == testEmail {
            foundOnSameConn = true
        }
    }
} catch {
    print("  Error: \(error)")
}

// Try with a new connection
print("\nReading on NEW connection (no sync):")
let readConn = try db.connect()
var foundOnNewConn = false
do {
    for row in try readConn.query("SELECT id, email FROM users WHERE id = \(uniqueId)", []) {
        let id = try row.getInt(0)
        let email = try row.getString(1)
        print("  Found: id=\(id), email=\(email)")
        if id == uniqueId && email == testEmail {
            foundOnNewConn = true
        }
    }
} catch {
    print("  Error: \(error)")
}

// Try with explicit sync + new connection
print("\nReading on NEW connection AFTER sync():")
try db.sync()
let syncedConn = try db.connect()
var foundAfterSync = false
do {
    for row in try syncedConn.query("SELECT id, email FROM users WHERE id = \(uniqueId)", []) {
        let id = try row.getInt(0)
        let email = try row.getString(1)
        print("  Found: id=\(id), email=\(email)")
        if id == uniqueId && email == testEmail {
            foundAfterSync = true
        }
    }
} catch {
    print("  Error: \(error)")
}

print("\n--- Results ---")
print("Same connection:      \(foundOnSameConn ? "SUCCESS" : "FAIL")")
print("New connection:       \(foundOnNewConn ? "SUCCESS" : "FAIL")")
print("After sync() + new:   \(foundAfterSync ? "SUCCESS" : "FAIL")")
