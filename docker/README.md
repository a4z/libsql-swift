# Docker Notes

## Testing in Docker (macOS host)

- `swift test --build-path .build-linux-amd64 --parallel --num-workers 4 -v` works.
- Higher `--num-workers` increases hang likelihood.
- In emulated containers, `swift test` can hang even with lower workers.
- Native Linux runs are stable.

at least, so far ,not sure what the problem in Docker is
problem on Docker on Mac
