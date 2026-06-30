<p align="center">
  <img src="photo/logo.png" alt="CBlerr Logo" width="250" />
</p>

<h1 align="center">CBlerr Compiler</h1>

<p align="center">
  <b>A pure AOT compiler that works directly with the physics of silicon.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-v5.3_STABLE-brightgreen.svg?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/platform-Win%20%7C%20Linux%20%7C%20WASM-lightgrey.svg?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/python-3.10+-yellow.svg?style=flat-square" alt="Python">
</p>

<p align="center">
  <a href="#architecture">Architecture</a> •
  <a href="#whats-new">What's New</a> •
  <a href="#benchmarks">Benchmarks</a> •
  <a href="#quick-start">Quick Start</a>
</p>

---

# The Right to Bare Metal

Stop feeding virtual machines. CBlerr is the last frontier of systems programming for hardcore developers and solo engineers. No JIT hacks, heavyweight JVMs, or bloated runtimes. Just a mathematically precise stream of machine instructions and absolute control over the CPU.

<a id="whats-new"></a>

# What's New in v5.3 (STABLE RELEASE)

Version 5.3 introduces major architectural improvements:

- **Added `defer` and the bump arena allocator** — zero overhead when leaving a scope.
- **Completely redesigned memory management** — maximum safety without sacrificing performance.
- **New math engine** — mathematical operations are now 2–7× faster than the standard libc.
- **Strict Type Checker** — detects type mismatches during compilation.
- **Memory Leak Analyzer** — performs static ownership graph analysis before code generation.
- **Improved Linux compilation** — complete autonomy (Bypassing Glibc), producing binaries that run on virtually any kernel.
- **Powerful compilation flags** — direct control over vectorization (AVX128/256/512), linker selection (LLD), compiler backend (GCC/Clang), plus WASM and DLL support.

---

<a id="architecture"></a>

# Architecture

## Safety Without Borrow Checker Slavery

Rust attempted to solve memory corruption by turning development into bureaucratic lifetime management. CBlerr embeds Fat Strings and Fat Pointers (`{char* data; long length;}`) into its DNA. The compiler injects machine-level bounds checking, automatically preventing buffer overflows. You stay safe without fighting the language.

## Static Analysis at Compile Time

You don't need a garbage collector when your compiler is smarter than you. The built-in StaticMemoryAnalyzer constructs an ownership graph in roughly 70 ms. Forgot to call `free` before `return`? The compiler points it out before even generating C code. No runtime surprises.

## Surgical Control Over Silicon

Direct access to the processor through `-avx512`, `-avx256`, and `-avx128`.

The compiler understands hardware realities: excessive vectorization can trigger thermal frequency throttling. The `-native` flag inspects the processor via CPUID and generates binaries optimized for the current CPU with minimal cache misses.

## Eternal Windows Legacy and Linux Autonomy

- **Windows:** When targeting Windows (`-t windows`), the compiler links essential functions directly against the system `msvcrt.dll`. Applications can run even on Windows XP x64 without missing UCRT/DLL issues.

- **Linux:** Depending on glibc complicates deployment. CBlerr translates allocator and I/O calls directly into inline assembly `syscall` instructions. The resulting ELF binary is completely self-contained, running anywhere from legacy servers to a Steam Deck.

---

# Syntax & Features (Win32 API + Inline ASM)

Python-like syntax (Clean & Strict) with static typing and assembly macros:

```python
extern def QueryPerformanceCounter(lpPerformanceCount: *i64) -> int

@asm("rdtsc")
def get_cpu_cycles() -> u64:
    return 0 # The compiler injects the ASM directly here

def main() -> int:
    ticks: i64 = 0
    QueryPerformanceCounter(&ticks)

    # Walrus operator, static typing, and Fat Strings
    if (title := "CBlerr v5.3 Engine").length > 0:
        print(title)

    # Automatically expanded at the end of the scope. Zero overhead.
    ptr: *void = malloc(1024 * 1024)
    defer:
        free(ptr)
        print("Memory nuked.")

    endofcode
```

---

<a id="benchmarks"></a>

# System-Level Dominance (Benchmarks)

Performance metrics that make mainstream platforms uncomfortable:

- **20.5 ms** — Cold startup of a complete Win32/OpenGL graphical application.
- **13.48 KB** — Final `.exe` size of an entire 2D game (ragdoll physics + particles) without packers.
- **6 CPU cycles** — Per Fibonacci loop iteration thanks to Zero-Cost Abstractions.
- **0.484 sec** — Full 8-stage compilation pipeline for 153 KB of source code.
- **840 bytes** — Size of a `Hello, World!` binary (Freestanding Mode, Stripped, No-CRT).

| Feature | CBlerr v5.3 | C / C++ | Rust | Go | Java / C# |
|:--|:--|:--|:--|:--|:--|
| **Startup Time** | **~20 ms (Instant)** | ~20 ms | ~25 ms | ~150 ms (GC init) | ~500 ms – 2 s (VM) |
| **Binary Size** | **~840 bytes** | ~15–260 KB | ~300 KB–3 MB | ~2 MB | Requires JRE / CLR |
| **Memory Safety** | **Yes (Fat Pointers + AST)** | No (Segfaults) | No (Borrow Checker) | Yes (GC) | Yes (VM) |
| **Build Time** | **< 0.5 sec** | Slow | Very Slow | Fast | Depends on build system |
| **Runtime** | **None** | libc / UCRT | libc | Built-in | JVM / CLR |

---

# CBlerr Console Compiler (CCC)

The console interface communicates with engineers directly and efficiently. A built-in Levenshtein algorithm catches typos, while the integrated profiler measures every compilation stage.

```text
┏━╸┏┓ ╻  ┏━╸┏━┓┏━┓
┃  ┣┻┓┃  ┣╸ ┣┳┛┣┳┛
┗━╸┗━┛┗━╸┗━╸╹┗╸╹┗╸

--------------------------------------------------------
             CBlerr Compiler (CCC) v5.3
--------------------------------------------------------

Usage:
python build/cli.py <source_file.cbl | project.cblproj> [options]

REQUIRED OPTIMIZATION FLAGS (pick one):
  -fast       Maximum performance
  -small      Minimum binary size

EXTRA OPTIONS:
  -t <os>         windows | linux | wasm | winlib
  -run            Run after compilation
  -asm            Generate assembly output
  -o <file>       Output filename
  -m32            x86 build
  --gcc           Use GCC
  --clang         Use Clang
  --lld           Use the LLD linker
  --stack-size    Stack size
  -native         Optimize for the current CPU
  -v3             x86-64-v3
  -avx512         AVX-512
  -avx256         AVX2
  -avx128         AVX
  --time          Compilation profiling
  -derr           Detailed memory dump
```

---

<a id="quick-start"></a>

# Quick Start

Deploy the CBlerr v5.3 toolchain in just a few minutes.

Requirements: Python 3.10+ and GCC / Clang / LLVM (or MinGW on Windows).

## 1. Clone the repository

```bash
git clone https://gitlab.com/tankman02/cblerr.git
cd cblerr
```

## 2. Create a program

```python
def main() -> int:
    print("Target acquired. CBlerr v5.3 active.")
    endofcode
```

## 3. Build

Maximum performance:

```bash
python build/cli.py hello.cbl -fast -native
```

Standalone Linux ELF:

```bash
python build/cli.py hello.cbl -t linux -fast
```

DLL library:

```bash
python build/cli.py engine.cbl -t winlib
```

---

# Community & Links

<p align="center">
  🌐 <a href="https://cblerr.netlify.app">Official Website</a> •
  🦊 <a href="https://github.com/tankman04/cblerr">GitHub</a> •
  🦊 <a href="https://gitlab.com/tankman02/cblerr">GitLab</a> •
  📢 <a href="https://t.me/tankman02d6">Telegram Channel</a> •
  👤 <a href="https://t.me/tankman02">Author</a>
</p>