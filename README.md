# ripwc

`ripwc` is a high-performance rewrite of the GNU `wc` (word count) utility, implemented in Rust for speed and efficiency. It counts lines, words, characters, bytes, and maximum line lengths in files or directories, optimized for low-memory systems (e.g., 4GB RAM) while processing large datasets. Using unsafe Rust for pointer arithmetic, loop unrolling, and `rayon` for parallelism, `ripwc` achieves up to ~19.5x speedup (in my tests).

## Features
- **Counts**: Lines (`-l`), words (`-w`), characters (`-m`), bytes (`-c`), and maximum line length (`-L`).
- **Recursive Mode**: Processes directories recursively with `-r`.
- **Concurrency**: Uses `rayon` with up to X threads where X is the number of CPU cores, processing files (>512KB) in parallel and batching small files (<512KB) sequentially to reduce thread overhead.
- **Low Memory Usage**: ~1MB heap-allocated buffers minimize syscalls per thread (~8MB peak with 8 threads), suitable for low-RAM systems.
- **Optimisations**:
    - Unsafe Rust for pointer arithmetic and 8-byte loop unrolling.
    - Static whitespace lookup table for efficient word counting.

## Notes
- **wc Limitations**:
    - Single-threaded, leading to high user time.
    - Inefficient I/O for large datasets, resulting in ~40-50x slower performance.

- **Test Conditions**:
    - Random binary files (from `/dev/urandom`) may yield different counts (e.g., words) than text files, but byte counts are consistent.
    - Disk sync (`--prepare 'sync'`) ensures fair I/O comparisons.


## Installation
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/LuminousToaster/ripwc
   cd ripwc
   ```

2. **Build the Project**:
   ```bash
   cargo build --release
   ```
   The binary will be at `target/release/ripwc`.

## Usage
Run `ripwc` with the following syntax:
```bash
./target/release/ripwc [OPTIONS] <FILE_OR_DIRECTORY>...
```

### Options
- `-c, --bytes`: Print byte counts.
- `-m, --chars`: Print character counts (non-zero bytes).
- `-l, --lines`: Print newline counts.
- `-w, --words`: Print word counts (non-whitespace sequences).
- `-L, --max-line-length`: Print maximum line length.
- `-r, --recursive`: Recursively process directories.
- `-v`: Print verbose output (processing each file).
- `-h`: Print help.
- `-V`: Print version.
- Default (no flags): Prints lines, words, and bytes.

### Examples
- Count lines, words, and bytes for a single file:
  ```bash
  ./target/release/ripwc file.txt
  ```
  Output: `lines: 100 words: 500 bytes: 2048 file.txt`

- Process a directory recursively:
  ```bash
  ./target/release/ripwc -r /path/to/dir
  ```
  Output: Per-file counts and totals, e.g., `lines: 60966229 words: 240316537 bytes: 15203482929 total`

- Count only bytes and characters:
  ```bash
  ./target/release/ripwc -c -m file.txt
  ```
  Output: `chars: 2000 bytes: 2048 file.txt`

## Generating Test Files
The project includes a Bash script (`generate_files.sh`) to create random binary files for testing `ripwc`’s performance. The data is taken from ``/dev/urandom``

### Script Usage
```bash
./generate_files.sh <number_of_files> <size_in_MB>
```
- `<number_of_files>`: Number of files to generate (positive integer).
- `<size_in_MB>`: Size of each file in megabytes (positive integer).

### Example
Generate 100 files, each 10MB:
```bash
chmod +x generate_files.sh
./generate_files.sh 100 10
```
- Creates a `random_files/` directory with files `random_file_1.bin` to `random_file_100.bin`.
- Total data: 1000MB (1GB).
- Output:
  ```
  Generating 100 files, each with 10 MB of random data...
  Completed! Generated 100 files of 10 MB each in the 'random_files' directory.
  Total data generated: 1000 MB
  ```

### Testing with Generated Files
Run `ripwc` on the generated files:
```bash
./target/release/ripwc -r random_files/
```
Compare with GNU `wc`:
```bash
wc -lwc random_files/*
```

## Benchmarking
To measure performance, use `hyperfine`:
```bash
hyperfine --warmup 3 --min-runs 10 --prepare 'sync' "./target/release/ripwc -r /path/to/dir" "wc /path/to/dir/*"
```
Or `time`:
```bash
time ./target/release/ripwc -r /path/to/dir
time wc -lwc /path/to/dir/*
```

# ripwc benchmark results

This document presents benchmark results comparing `ripwc` against GNU `wc`. Tests were conducted using `hyperfine` with 5 runs each, after warming up with 3 runs and syncing the disk (`--prepare 'sync'`). Three test cases were evaluated:

1. **40 files, 300MB each** (12GB total).
2. **1000 files, 3MB each** (3GB total).
3. **1 file, 3000MB** (3GB total).

Files were generated using `generate_files.sh` (e.g., `./generate_files 40 300`). Benchmarks measured wall-clock time, user time, and system time for `ripwc -r random_files` and `wc random_files/*`.

The benchmarks were run on a 4C/4T I5-7600k OC'd to 5GHz, 16GB RAM, Arch Linux with kernel 6.14.6-arch1-1. It should be noted that I ran the benchmarks after a fresh reboot and before any apps were opened by me with the exception
of Konsole and a tmux server.

Also note, the system used to benchmark is encrypted with LUKS2:
```
type:    LUKS2
cipher:  aes-xts-plain
keysize: 512 bits
key location: keyring
device:  /dev/sdc2
sector size:  512
offset:  32768 sectors
size:    478949376 sectors
mode:    read/write
```

## Summary Table

| Test Case                | Total Data | ripwc Time (mean ± σ) | wc Time (mean ± σ) | Speedup (ripwc vs. wc) |
|--------------------------|------------|-----------------------|--------------------|------------------------|
| 40 files, 300MB each     | 12GB       | 5.576 s ± 0.663 s     | 272.761 s ± 0.350 s | 48.92 ± 5.82x         |
| 1000 files, 3MB each     | 3GB        | 1.420 s ± 0.077 s     | 68.610 s ± 1.168 s | 48.33 ± 2.76x         |
| 1 file, 3000MB           | 3GB        | 4.278 s ± 0.021 s     | 68.001 s ± 0.075 s | 15.90 ± 0.08x         |

## Detailed Results

### Test Case 1: 40 Files, 300MB Each (12GB Total)
Command: `./generate_files 40 300`
```bash
hyperfine --warmup 3 --min-runs 5 --prepare 'sync' "./target/release/ripwc -r random_files" "wc random_files/*"
```

- **ripwc**:
    - Time: 5.576 s ± 0.663 s
    - User: 15.990 s, System: 1.625 s
    - Range: 5.067 s … 6.677 s
- **wc**:
    - Time: 272.761 s ± 0.350 s
    - User: 270.418 s, System: 1.140 s
    - Range: 272.406 s … 273.230 s
- **Speedup**: 48.92 ± 5.82x

### Test Case 2: 1000 Files, 3MB Each (3GB Total)
Command: `./generate_files 1000 3`
```bash
hyperfine --warmup 3 --min-runs 5 --prepare 'sync' "./target/release/ripwc -r random_files" "wc random_files/*"
```

- **ripwc**:
    - Time: 1.420 s ± 0.077 s
    - User: 4.458 s, System: 0.559 s
    - Range: 1.362 s … 1.553 s
- **wc**:
    - Time: 68.610 s ± 1.168 s
    - User: 68.206 s, System: 0.231 s
    - Range: 67.963 s … 70.692 s
- **Speedup**: 48.33 ± 2.76x

### Test Case 3: 1 File, 3000MB (3GB Total)
Command: `./generate_files 1 3000`
```bash
hyperfine --warmup 3 --min-runs 5 --prepare 'sync' "./target/release/ripwc -r random_files" "wc random_files/*"
```

- **ripwc**:
    - Time: 4.278 s ± 0.021 s
    - User: 3.950 s, System: 0.314 s
    - Range: 4.256 s … 4.301 s
- **wc**:
    - Time: 68.001 s ± 0.075 s
    - User: 67.618 s, System: 0.232 s
    - Range: 67.896 s … 68.091 s
- **Speedup**: 15.90 ± 0.08x

## Performance Graphs

### Wall-Clock Time Comparison
The following ASCII bar chart compares mean wall-clock times (in seconds) for `ripwc` and `wc` across the test cases. The scale is normalized to the maximum `wc` time (272.761 s).

```
Legend: █ = ripwc, ▓ = wc
40 files, 300MB (12GB):
ripwc: █████ 5.576 s
wc:    ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 272.761 s

1000 files, 3MB (3GB):
ripwc: █ 1.420 s
wc:    ▓▓▓▓▓▓▓▓▓▓▓▓▓ 68.610 s

1 file, 3000MB (3GB):
ripwc: ████ 4.278 s
wc:    ▓▓▓▓▓▓▓▓▓▓▓▓▓ 68.001 s
```

### Speedup Comparison
The following ASCII bar chart shows the speedup of `ripwc` over `wc` (times faster) for each test case. The scale is normalized to the maximum speedup (48.92x).

```
Legend: █ = Speedup
40 files, 300MB (12GB):     ████████████████████████████████████████████████ 48.92x
1000 files, 3MB (3GB):      ███████████████████████████████████████████████ 48.33x
1 file, 3000MB (3GB):       ███████████████ 15.90x
```

## Analysis
- **40 Files, 300MB (12GB)**:
    - `ripwc` excels with large files processed in parallel, achieving ~49x speedup due to `rayon` parallelism (up to `num_cpus` threads) and 1MB buffers.
    - High user time (15.990 s) vs. wall-clock (5.576 s) indicates effective multi-core utilization (~287% CPU).
    - Throughput: 12GB / 5.576 s ≈ 2152 MB/s.

- **1000 Files, 3MB (3GB)**:
    - `ripwc` maintains ~48x speedup, leveraging small-file batching (<512KB) to reduce thread overhead.
    - Lower system time (0.559 s) reflects efficient I/O for many small files.
    - Throughput: 3GB / 1.420 s ≈ 2113 MB/s.

- **1 File, 3000MB (3GB)**:
    - Lower speedup (~16x) due to single-threaded processing (no parallelism for one file).
    - `ripwc` still outperforms `wc` with optimized I/O (1MB buffer) and unsafe Rust counting.
    - Throughput: 3GB / 4.278 s ≈ 701 MB/s.

## Contributing
- Report issues or suggest features at [https://github.com/LuminousToaster/ripwc](https://github.com/LuminousToaster/ripwc).
