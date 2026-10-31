# coslcs

Two strings in, shared bytes out.

2096 bytes of state. Zero allocations. 40 lines of zig.

```console
$ coslcs README.md new.md
matched 729 pair(s)
source  729/793 (91.9%)
target  729/795 (91.7%)
```

It is not a minimal diff. It is a coverage number and the byte positions.

## How

Two indices, both at zero. One 256-entry table.

Loop:

1. Either index at the end. Stop.
2. Bytes equal. Emit, advance both.
3. Otherwise fill the table from `target[i..]`, first occurrence of each value.
4. Scan `source[i..]`. Keep the smallest `source_offset + target_offset`.
5. Emit that pair. Advance both one past it.

Step 4 picks the cheapest place to resume. The sum is the bytes skipped on each
side, which is the indel count to get both indices there.

```zig
for (self.source[self.source_index..], 0..) |item, offset| {
    if (offset >= best_sum) break;   // no later position can be smaller
}
```

The `break` is the whole thing. Source offset only grows, so once it alone
beats the best sum, nothing later can win. Scan stops early.

Delete the `break` and the output is identical. The speed is not.

Indices only move forward. That is why 2096 bytes is enough.

## Speed

1024 random bytes each side. 18 µs at a 255-symbol alphabet. 36 µs at 2.

Against Ratcliff-Obershelp, the thing inside Python's `difflib`:

| alphabet | coslcs matched | RO matched | speed |
|---|---|---|---|
| 2 | 702 | 327 | 88x |
| 4 | 542 | 322 | 29x |
| 16 | 334 | 118 | 11x |
| 64 | 175 | 60 | 2.6x |
| 255 | 89 | 23 | 1.2x |

More matched bytes in every row. Faster in every row. No row where you trade
one for the other.

Identical input is 200,000x: 0.7 µs against 152.8 ms, same 1024 matched bytes.
`find_longest_match` checks every pair of positions even when the answer is at
the start of both strings. Cubic work to learn nothing. coslcs is linear there.

The baseline was checked before it was trusted. C port of `find_longest_match`
against CPython's `difflib`, same inputs, scaling exponent at alphabet 2 from
256 to 512 bytes: **2.19 vs 2.20**. Two languages, two PRNGs, one number.

## What it does on edits

793-byte markdown file, one change at a time:

| change | matched | coverage |
|---|---|---|
| none | 793 | 100.0% |
| 64 bytes `e` -> `E` | 729 | 91.9% |
| 186 bytes `the` -> `xyz` | 607 | 76.5% |
| one 9-byte line moved to end | 711 | 89.7% |
| a third of the file moved to end | 256 | 32.3% |
| 25% byte rotation | 241 | 30.4% |
| different document | 230 | 29.0% |

Two rules. Nothing else.

**Order kept, loss is exactly the damage.** 64 substitutions, 64 bytes lost.
186 substitutions, 186 bytes lost. Alignment re-establishes on the next
matching byte, so it does not spread.

**Opening moved, loss is everything.** Rotation scores 30.4%. Unrelated
document scores 29.0%. 11 bytes apart. First byte misaligned and both indices
are off by the rotation distance. They cannot go back, so the right region is
never reached.

A moved block scores zero. Its bytes sit after the current target index, so
their offsets are large, so incidental matches already nearby win. The scan
walks past it.

## Use if

- Screen thousands of pairs, send the best hundred to an exact aligner. 18 µs
  each.
- No `malloc` anywhere: WASM, firmware, packet parsers.
- Diff preview that has to finish before the next keystroke.
- Find where two logs or replicas stopped agreeing.

## Do not use if

- **You want a minimal edit script.** It gets 65 to 85% of the true LCS on
  high-entropy data. One greedy pick per pair, never revisited. Use Myers or
  `edlib`.
- **Opening bytes moved.** Coverage drops to chance and stays there. Removing
  the `break` would fix it and cost you the speed.
- **Genomes.** No gapped scoring, no reverse complement, no E-value. Two
  AT-rich repeats with no common origin will score high and you will have no
  way to tell. Rearranged content scores zero, and rearrangement is normal in
  genomic data.

## API

```zig
var iterator = coslcs.ClosestOffsetSumLCS(usize).init(source, target);
while (iterator.nextPair()) |pair| {
    // pair.value, pair.source_index, pair.target_index
}
```

`next()` drops the positions. `reset()` rewinds both indices. Index type is a
parameter: `u32` halves state to 1040 bytes, caps input at 4 GiB.

```c
cos_lcs *lc = cos_lcs_create_str("old", "new");
cos_lcs_pair pair;
while (cos_lcs_next_pair(lc, &pair)) { /* ... */