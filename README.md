# coslcs

**Find shared bytes without solving the full LCS problem.**

coslcs walks two byte sequences, always picking the matching byte pair closest to the current positions, emitting it, and advancing past it.

Dynamic-programming LCS evaluates all `n*m` position pairs to guarantee the longest result. coslcs skips the grid: equal leading bytes match instantly, a per-byte table replaces comparisons, and the source scan stops early. Identical inputs run in `O(n)` instead of `O(nm)`.

**Trade-off: a common subsequence, not the longest one.**

## Speed

Measured average: `32x` faster than DP LCS, at `83%` of optimal subsequence length.

Allocation-free, constant memory, includes a C API. Requires Zig 0.16.0.

```sh
zig build test
zig build bench --release=fast
```
