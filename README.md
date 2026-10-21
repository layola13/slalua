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
src/tok.sla        token kinds + Token struct
src/lexer.sla      Lua 5.5 lexer (comments, long strings, numerals)
src/rt.sa          low-level macros (file/format buffer access)
src/strutil.sla    string helpers over sa_fmt buffer handles
src/ast.sla        arena AST + node ids
src/parse_core.sla parser cursor + arena/list builders
src/parse_expr.sla Lua expression grammar + precedence
src/parse_stmt.sla Lua statements, blocks, local/global attributes
src/parser.sla     parser entry point
src/value.sla      Value tagged union + conversions
src/interp_core.sla arenas (Env/Table/Func), globals, control codes
src/interp_expr.sla expression evaluator, calls, closures, indexing
src/interp_stmt.sla statements, loops, blocks, goto
src/builtins.sla   base / string / table / math / os builtins
src/interp.sla     evaluator entry point
docs/sla-defects.md  defects found while porting
```

## Status

Lexer and parser complete. Both stages handle all 34 files in the Lua 5.5
`testes/` suite without errors, including `#` shebangs, long-bracket
strings/numerals, ISO-8859 source bytes, named varargs (`...t`), and the Lua 5.5
`global` / `local <attrib>` declarations. The largest file, `math.lua`, yields
8746 tokens and 6455 AST nodes (`api.lua`).

Run the front-end checks with:

```sh
sla build src/probe_lexer_all.sla --out .sla-cache/lexall.sa
sa build-exe .sla-cache/lexall.sa -o /tmp/lexall
/tmp/lexall

sla build src/probe_parse_all.sla --out .sla-cache/parseall.sa
sa build-exe .sla-cache/parseall.sa -o /tmp/parseall
/tmp/parseall
```

The evaluator runs blocks, locals/globals, assignment, numeric and generic
loops, `repeat`, closures, method calls, varargs (including Lua 5.5 named
varargs), table constructors, `goto`, `pcall`/`error`, and a core set of base,
`string`, `table`, `math` and `os` functions. It executes
`tests/hello.lua` and `tests/features.lua` and advances through
`testes/vararg.lua` up to the Lua 5.5 named-vararg `n` validation checks.

Run the evaluator smoke test with:

```sh
sla build src/probe_run.sla --out .sla-cache/run.sa
sa build-exe .sla-cache/run.sa -o /tmp/run
/tmp/run
```

Each stage is compiled with `sla check`, `sla build` and executed before moving
on. Defects found so far are tracked in `docs/sla-defects.md`. Coroutines,
metamethod coverage (`__newindex`, `__call`, arithmetic), `require`, and the
debug library are next.

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
