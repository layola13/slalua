# Sla defects found while porting Lua

Environment: SA 0.1.6, `sa_plugin_sla` 0.1.4, Zig 0.17.0, LLVM 14,
Linux x86_64.

Each entry records a minimal reproducer, the observed behaviour, the expected
behaviour, and the workaround used by `slalua` until the compiler is fixed.

## D-001 `build-exe` rejects enum + Vec + pointer probe on the direct SAB path

Reproducer: `src/probe1.sla`.

`src/probe1.sla` contains an enum with payloads, a `Vec<Entry>` where `Entry`
holds two enum values, `match` over the enum, `STR_PTR`/`STR_LEN` macros and
`PTR_READ_U8`.

Observed:

```
$ sla check src/probe1.sla
Sla Compiler: Successfully parsed and verified syntax and types of src/probe1.sla.
$ sla build-exe src/probe1.sla -o /tmp/probe1
SAB Error: direct SLA-to-SAB lowering failed: error.UnsupportedSabDirectFeature
```

Expected: the direct SAB path reports which feature/node is unsupported, or
lowers the program. It currently reports only the generic error, which makes
bisecting a large file impractical.

Workaround: compile through the SA compatibility path:

```
sla build src/probe1.sla --out /tmp/probe1.sa
sa build-exe /tmp/probe1.sa -o /tmp/probe1
```

Status: open. Needs minimization (see `src/probe*.sla`).
