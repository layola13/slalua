# slalua agent rules

- Hard limit: every `*.sla` source file must stay at or below **700 lines**.
  When approaching the limit, split into modules and combine them with
  `@import`; do not compress formatting or remove blank lines to dodge the
  limit.
- Build/test with Zig 0.17 toolchain:
  `sla check <file>`, then `sla build <file> --out .sla-cache/x.sa` and
  `sa build-exe .sla-cache/x.sa -o /tmp/x` (fallback path until direct SAB
  lowering covers the feature set).
- Record every Sla compiler defect in `docs/sla-defects.md` with a minimal
  reproducer.
- Use UTF-8 for all text files.
