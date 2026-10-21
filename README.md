# slalua

Lua refactored into [Sla](https://github.com/layola13/sa_plugins) (the high-level
frontend of SA), used as a real-world stress test for the Sla compiler.

- Upstream reference: <https://github.com/lua/lua> @ `8cb93bad` (Lua 5.5.1 work tree)
- Toolchain: SA 0.1.6 + `sa_plugin_sla`, built with Zig 0.17.0 and LLVM 14

## Goal

Porting Lua to Sla is not a mechanical C transliteration. The C implementation
leans on pointer arithmetic, unions, `longjmp`, and a precise incremental GC.
`slalua` rebuilds the same semantics with Sla's affine types, `Vec`, enums and
pattern matching, using arena indices for the value graph instead of raw
recursive pointers.

The secondary goal is to find, minimize and fix real defects in Sla itself.

## Layout

```
src/main.sla       entry point / CLI
src/lexer.sla      Lua lexer
src/ast.sla        arena AST + node ids
src/parser.sla     recursive-descent parser
src/value.sla      Value / Table / Function arenas
src/interp.sla     tree-walking evaluator
src/stdlib.sla     base / string / table / math libraries
docs/sla-defects.md  defects found while porting
```

## Status

Early bootstrap. Lexer/parser/evaluator are being written incrementally; each
stage is compiled with `sla check`, `sla build` and executed before moving on.

## Build

```sh
export PATH=$HOME/.sa/bin:$PATH
export SA_PLUGIN_DEV=1
export SA_STD_DIR=$HOME/.sa/std
sla check src/main.sla
sla build src/main.sla --out .sla-cache/main.sa
sa build-exe .sla-cache/main.sa -o slalua
```

## License

The ported code is a derived work of Lua and keeps the Lua MIT license.
See `LICENSE`.
