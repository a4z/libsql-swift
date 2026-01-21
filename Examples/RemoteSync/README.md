# RemoteSync

Example to test read-your-writes behavior with embedded replicas.

## Running

```bash
TURSO_DATABASE_URL="..." TURSO_AUTH_TOKEN="..." swift run RemoteSync
```

## Read-Your-Writes Behavior

When using embedded replicas, `readYourWrites` allows reading data immediately after writing without calling `sync()`. However, there are limitations:

| Operation                  | Same conn | New conn | After sync() |
| -------------------------- | --------- | -------- | ------------ |
| `execute()`                | ✅        | ✅       | ✅           |
| `executeBatch()`           | ❌        | ❌       | ✅           |
| `execute("DROP TABLE...")` | ❌        | ✅       | ✅           |

**Key findings:**

- `execute()` works correctly with read-your-writes
- `executeBatch()` does NOT trigger read-your-writes sync - call `sync()` manually
- Schema changes like `DROP TABLE` are not visible on the same connection, but a new connection will see them
