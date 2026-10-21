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

在 Windows PowerShell 环境中处理包含中文的文件时，必须显式使用 UTF-8 编码。

代码与文本文件读取、统计行数、文本搜索优先使用封装增强工具（read_file, read_lines, count_lines, grep_search 等），避免在终端中使用慢速命令阅读文件或搜索代码
写入文本文件优先使用 apply_patch；如必须用 PowerShell 写文件，使用 Set-Content -Encoding UTF8 或 Add-Content -Encoding UTF8
不要用未指定编码的 Set-Content 或 Out-File 处理中文、Markdown、TOML、JSON 等文本文件
终端输出出现乱码时，先用 UTF-8 重新读取确认，不要直接认定文件内容损坏
