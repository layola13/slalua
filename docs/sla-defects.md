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

## D-002 struct literals for types from another `@import` fail to parse

Reproducer: `src/probe_struct_def.sla`, `src/probe_struct_use.sla`.

`probe_struct_def.sla` declares `struct Foo`, and `probe_struct_use.sla`
imports it and writes `let a = Foo { x: 1, y: 2 };`.

Observed:

```
Syntax Error: failed to parse src/probe_struct_use.sla:5:17: error.SyntaxError
  |     let a = Foo { x: 1, y: 2 };
  |                 ^ found '{', expected semicolon
```

The parser only recognises a struct literal when the type name is in its local
`known_types` list, but imported type names are not seeded before the importing
module is parsed. Declaring `Foo` in the same file works.

Expected: imported type names participate in struct-literal parsing.

Workaround: define a constructor in the module that owns the type, e.g.
`fn token_new(...) -> Token { return Token { ... }; }`, and call the
constructor from importers. `src/tok.sla` does this.

Status: open.

## D-003 statement `if`/`else` still requires equal branch tail types

Reproducer: `src/probe_if_tail.sla`.

A nested `if`/`else` statement, terminated with `;`, inside a `while` body in an
`impl` method.

Observed:

```
$ sla check src/probe_if_tail.sla
Type Check Error: failed to verify types: if expression branch type mismatch
(error.TypeMismatch)
```

The then-branch tail is an assignment (`bool`) while one else-branch tail is a
call returning `u8` (or a nested statement), so `blockTailExprType` compares two
primitive types even though the `if` is used as a statement.

Expected: a semicolon-terminated `if` statement discards its value and does not
require both branches to produce the same tail type.

Workaround: flatten nested `else` chains into guard-style `if` statements with
`continue`/`return` in each branch, so no branch has a mismatched tail
expression. `src/lexer.sla` was rewritten this way.

Status: open.

## D-004 `FS_READ_BUFFER_FREE` macro traps with `UseAfterMove`

Reproducer: `src/probe_free_macro.sla`.

The standard macro expands to:

```
%out_status = call @sa_fs_read_buffer_free(^%buffer)
```

Observed after `sla build` + `sa build-exe`:

```
{"trap":"UseAfterMove","trap_code":1009,...,
 "source_text":"    !buf","register":"buf",
 "message":"moved value is no longer usable"}
```

Expected: the handle is consumed once and the buffer is released.

Workaround: call the extern directly without the move prefix:

```
let st = sa_fs_read_buffer_free(buf);
```

The same pattern is used by `sa_plugin_sla/tests/test_unit_fallible_extern_payload_direct.sla`.
`src/probe_lexer_all.sla` frees every source buffer this way.

Status: open.

## D-005 `FS_READ_TO_STRING` rejects non-UTF-8 source files

Reproducer: `src/probe_utf8_read.sla` against
`../lua/testes/strings.lua` (ISO-8859 bytes inside Lua string literals).

Observed:

```
text_handle=0 raw_handle=4
```

`SLA_FS_READ_TO_STRING` returns 0 for the file, while the byte-oriented
`sa_fs_read_file` reads it successfully.

Expected: a compiler frontend must be able to load arbitrary source bytes;
UTF-8 validation belongs to later stages.

Workaround: use `sa_fs_read_file` + `SLA_FS_BUFFER_DATA/LEN` and copy bytes with
`s_from`. The lexer now reads all 34 Lua test files this way.

Status: open (behavioural limitation, documented).

## D-006 Cyclic `@import` fails when the cycle returns to the root file

Reproducer: `src/probe_cyc_a.sla` / `src/probe_cyc_b.sla`
(`a` imports `b`, `b` imports `a`, and `a` is the build root).

Observed:

```
Type Check Error: failed to verify types:
Redeclaration: function `fa` is already defined (error.Redeclaration)
```

The same cycle compiles when a third root file imports `a`: the loader detects
the already-visited module. Only re-entering the *root* module duplicates its
definitions.

Workaround: keep import cycles below the root, or move shared definitions into
a third module imported by both sides.

Status: open.

## D-007 Affine `Vec` parameter consumed on one `if` branch

Reproducer: passing a `Vec` by value to a helper, consuming it in one branch of
an `if`, and falling through to a merge point on the other branch:

```
error[PhiStateConflict]: incoming control-flow states do not agree
  register: args
  state: expected Active, actual Consumed
```

The diagnostic is accurate but the source pattern looks harmless because the
consuming branch returns before the merge.

Workaround: borrow the vector (`fn f(args: &Vec<T>)`, call `f(&args)`) and
rebuild result vectors explicitly.

Status: open (escape/liveness analysis).

## D-008 Bitwise operators and statement terminators

Not defects in the type system, but syntax that differs from C/Lua and cost
debugging time while porting the evaluator:

- `~` is not a bitwise-xor operator; use `^`. Unary complement must be written
  as `x ^ (-1)`.
- `&`, `|`, `^`, `<<`, `>>` are the supported integer bitwise operators.
- A statement `if ... { }` (with or without `else`) needs a trailing `;` when
  another statement follows it. Blocks for `while`/`for`/function bodies do not.
- Float literals do not accept exponent suffixes such as `1.0e308`; construct
  large constants with `sa_math_pow`.

Reproducers: the interpreter sources (`src/interp_expr.sla`).

Status: documented behaviour.

## D-009 Logical `&&` / `||` do not short-circuit

`&&` and `||` evaluate their right-hand side even when the result is already
decided by the left side. Bounds-
checked indexing on the right therefore turns a guard into a runtime panic:

```sla
if len(v) > 0 && v[0] > 0 { ... }
```

With an empty `v`, this reaches `v[0]` and aborts with `PANIC code=32`
(out-of-bounds). Reproducer: `src/probe_and.sla`.

This also breaks the Lua generic-for loop guard `if len(out) == 0 || out[0].tag
== VT_NIL`: an empty result vector still evaluates `out[0]` and panics.

Workaround: nest the tests instead of relying on short-circuit evaluation:

```sla
if len(v) > 0 {
    if v[0] > 0 { ... }
}
```

Status: open. The same pattern must be audited anywhere a guard protects an
index, division, or affine call; fixed occurrences in `B_GETMETA` and
`bi_require` were rewritten as nested `if`s.

## D-010 Conditional cast assignment corrupts the merged value

Assigning a *cast expression* to a local inside an `if` branch corrupts that
local at the merge point, even when the branch is never taken. For `f64` the
merged value becomes the integer value of the original IEEE-754 bit pattern,
converted back to `f64`.

Minimal reproducer (`src/probe_let_if.sla`, function `m1`):

```sla
fn m1() -> f64 {
    let x = 2.5;
    let i = 3;
    if false {
        x = i as f64;
    };
    return x;
}
```

Expected `2.5`; observed `4612811918334231000`, i.e. the integer value of the
bits of `2.5` (`0x4004000000000000`) rendered as an `f64`. The integer
direction is equally affected:

```sla
fn m3() -> i64 {
    let x = 7;
    let f = 2.5;
    if false {
        x = f as i64;
    };
    return x;
}
```

Expected `7`; observed `0`.

Only casts trigger it: plain constant assignment (`x = 9.0`), assignment of a
pre-computed value without a cast, and both-branch assignment all merge
correctly. It surfaced in `v_equal`:

```sla
let an = a.f;
if a.tag == VT_INT {
    an = a.i as f64;
};
return an == bn;
```

which made `2047.0 == 2047` evaluate to false. It also silently broke the
float branch of `math.abs` and the `math.min` reduction.

Workaround: return from each branch instead of assigning a cast across the
merge:

```sla
if a.tag == VT_INT {
    if b.tag == VT_INT { return a.i == b.i; };
    return (a.i as f64) == b.f;
};
if b.tag == VT_INT {
    return a.f == (b.i as f64);
};
return a.f == b.f;
```

Status: open (codegen). Reproducer: `src/probe_let_if.sla`.

## D-011: multiple branch assignment to one local is rejected by the SA backend

Trigger: a local that is written in more than one branch of an `if`/`else`
chain. The backend emits the SA text with two live definitions of the same
register (one per branch) and the SA verifier refuses the second definition.

Minimal reproducer:

```sla
fn f(c: i64) -> i64 {
    let r = 0;
    if c == 1 {
        r = 1;
    } else {
        if c == 2 {
            r = 2;
        } else {
            r = 3;
        };
    };
    return r;
}
```

Observed:

```
$ sla check f.sla
Sla Compiler: Successfully parsed and verified syntax and types of f.sla.
$ sla build f.sla --out f.sa
$ sa build-exe f.sa -o f
error[RegisterRedefinition]: register is already live
  in function @sla__f(c: i64) -> i64:
  register: r
```

Expected: the program compiles and `f` returns 1, 2 or 3. The branch
definitions never coexist, so a phi-style merge of the register is enough.

Workaround: give each branch its own variable, or use the read-before-write
idiom `r = r + (newvalue - r);`, which keeps one definition per path.

Status: open (codegen). Not reproduced with the sla 0.1.3 CLI in this
container, which lowers the same source with one definition per branch; the
trigger looks version dependent.

## D-012: a `Vec` copied out of a struct field keeps its pointer register live

Trigger: copying a `Vec` field of a struct into a local (`let x = self.items;`)
inside a loop. The temporary that holds the loaded pointer is never released,
so the register is still live when the loop head merges the two paths.

Minimal reproducer:

```sla
@import "sa_std/vec.sa"

struct Holder { items: Vec<i64> }

impl Holder {
    fn count(&self) -> i64 {
        let n = 0;
        while n < 3 {
            let x = self.items;
            n = n + len(x);
        }
        return n;
    }
}
```

Observed (after `sla build` + `sa build-exe`):

```
error[PhiStateConflict]: incoming control-flow states do not agree
  in function @sla__Holder_count(&self: ptr) -> i64:
  line 48145 (expanded 1140):     jmp L_WHILE_HEAD_0
  register: tmp_3
  state: expected Composite, actual Uninitialized
```

Expected: `count` compiles and returns 0; the copy is released at the end of
every iteration.

Workaround: do not copy the field - read `self.items` directly at the use site
(`n = n + len(self.items);`) - and avoid reference-passed `Vec`s; return a
freshly built `Vec` from helpers instead.

Status: open (escape/liveness analysis).

## D-013: a local shadowed in a nested block is reported as a redeclaration

Trigger: a `let` in an inner block that re-uses the name of a local declared in
an enclosing block of the same function.

Minimal reproducer:

```sla
fn f(c: i64) -> i64 {
    let msg = 1;
    if c == 1 {
        let msg = 2;
        return msg;
    };
    return msg;
}
```

Observed:

```
Type Check Error: failed to verify types:
Redeclaration: symbol `msg` is already defined (error.Redeclaration)
```

Expected: the inner `let msg` shadows the outer one inside the block, and the
outer `msg` stays visible after the block ends.

Workaround: use distinct names per scope (`msg1`, `msg2`, ...).

Status: open (type checker). Not reproduced with the sla 0.1.3 CLI in this
container, which accepts the shadowing; the trigger looks version dependent.

## D-014: a `&Vec<T>` parameter mutated inside a loop triggers a phi-state conflict

Trigger: a reference parameter that is mutated through the reference inside a
`while` loop. On the path that pushes into the vector the reference register is
`Active`, on the path that reaches the loop head it is `Composite`, so the
merge fails. Same diagnostic family as D-012, but the conflict is on the
reference parameter itself, not on a copied field.

Minimal reproducer:

```sla
@import "sa_std/vec.sa"

fn fill(buf: &Vec<i64>, n: i64) -> i64 {
    let i = 0;
    while i < n {
        buf.push(i);
        i = i + 1;
    }
    return len(buf);
}
```

Observed (after `sla build` + `sa build-exe`):

```
error[PhiStateConflict]: incoming control-flow states do not agree
  in function @sla__fill(&buf: ptr, n: i64) -> i64:
  line 48158 (expanded 1149):     jmp L_WHILE_HEAD_0
  register: buf
  state: expected Active, actual Composite
```

Expected: `fill` appends `n` elements to `buf` and returns its new length.

Workaround: return freshly built `Vec`s from helpers instead of mutating a
caller-provided `Vec` through a reference.

Status: open (escape/liveness analysis).

## D-015: `while { ... };` with a trailing semicolon is a parse error

Trigger: a `while` block followed by `;`. Sla demands the semicolon after an
`if` block (see D-008) but rejects it after a `while` block, and the message
does not name the offending construct - only a byte index into the expanded
import.

Minimal reproducer:

```sla
fn f(n: i64) -> i64 {
    let r = 0;
    while n > 0 {
        r = r + 1;
        n = n - 1;
    };
    return r;
}
```

Observed:

```
Unexpected prefix token: semicolon at index 98
Syntax Error: failed to parse f.sla:6:6: error.UnexpectedToken
  |
    4 |         r = r + 1;
    5 |         n = n - 1;
    6 |     };
      |      ^ found ';', expected valid expression or statement token
```

Expected: the trailing `;` that is mandatory after `if { ... };` should also be
accepted after `while { ... };`, or the diagnostic should point at the `while`
statement instead of an index into the expanded import.

Workaround: omit the `;` after a `while` block.

Status: open (parser). The `if`/`while` inconsistency makes the trap easy to
hit while porting.
