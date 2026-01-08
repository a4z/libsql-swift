# Code Coverage Guide

## Running Tests with Coverage

```bash
swift test --enable-code-coverage
```

This generates coverage data in `.build/debug/codecov/default.profdata`

---

## Viewing Coverage Reports

### 1. HTML Report (Recommended)

Generate a visual HTML report with line-by-line coverage:

```bash
xcrun llvm-cov show \
    .build/debug/LibsqlPackageTests.xctest/Contents/MacOS/LibsqlPackageTests \
    -instr-profile=.build/debug/codecov/default.profdata \
    -format=html \
    -output-dir=.coverage-report

# Open in browser
open .coverage-report/index.html
```

### 2. Terminal Summary

Quick coverage summary in the terminal:

```bash
xcrun llvm-cov report \
    .build/debug/LibsqlPackageTests.xctest/Contents/MacOS/LibsqlPackageTests \
    -instr-profile=.build/debug/codecov/default.profdata
```

### 3. File-Specific Coverage

See line-by-line coverage for a specific file:

```bash
xcrun llvm-cov show \
    .build/debug/LibsqlPackageTests.xctest/Contents/MacOS/LibsqlPackageTests \
    -instr-profile=.build/debug/codecov/default.profdata \
    Sources/Libsql/Libsql.swift
```

---

## Coverage Data Location

- **Raw coverage data**: `.build/debug/codecov/default.profdata`
- **HTML reports**: `.coverage-report/` (after generation)

---

## Current Test Suite

As of January 8, 2026:

- **Total tests**: 38
- **Test files**:
  - `LibsqlTests.swift` - 12 tests (basic functionality)
  - `ConnectionLifetimeTests.swift` - 6 tests (connection lifetime)
  - `DatabaseTypeTests.swift` - 8 tests (database type behaviors)
  - `MemoryManagementTests.swift` - 7 tests (memory management)
  - `MultipleConnectionsTests.swift` - 5 tests (multiple connections)

---

## Improving Coverage

### Areas to Check

1. **Error paths**: Are exception/error cases tested?
2. **Edge cases**: Boundary conditions, empty data, null values
3. **Type variations**: All `ValueRepresentable` types (Int, String, Double, Data, Blob)
4. **Database features**:
   - All bind methods (named vs positional)
   - Statement reset
   - Transaction rollback scenarios
   - Batch operations
   - Sync operations (remote databases)

### Adding Tests

When you identify gaps:

1. Look at the HTML report to see uncovered lines (marked in red)
2. Add tests to the appropriate test file
3. Re-run with coverage to verify improvement

### Example: Testing Uncovered Code

```bash
# 1. Generate HTML report
xcrun llvm-cov show \
    .build/debug/LibsqlPackageTests.xctest/Contents/MacOS/LibsqlPackageTests \
    -instr-profile=.build/debug/codecov/default.profdata \
    -format=html \
    -output-dir=.coverage-report

# 2. Open and identify red (uncovered) lines
open .coverage-report/index.html

# 3. Add tests for those code paths

# 4. Re-run tests with coverage
swift test --enable-code-coverage

# 5. Regenerate report to see improvement
```

---

## Tips

- **Focus on important code first**: Core functionality in `Libsql.swift`
- **Don't aim for 100%**: Some code paths (error handling, edge cases) might be hard to trigger
- **Test behavior, not implementation**: Good tests are valuable beyond coverage metrics
- **Use coverage to find gaps**: Missing tests often reveal missing documentation or unclear APIs

---

## Cleanup

The coverage data and reports can be removed:

```bash
# Remove coverage data
rm -rf .build/debug/codecov

# Remove HTML reports
rm -rf .coverage-report

# Full clean
swift package clean
```
