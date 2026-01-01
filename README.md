# markdown_monolith

An OCaml library and CLI tool to produce a single monolithic Markdown file by parsing with `omd`, detecting navigational TOC-like link lists using deterministic rules and weighted scoring, and inlining selected files.

## Features

- **AST-based Processing**: Uses the `omd` library to parse and traverse Markdown documents as an Abstract Syntax Tree
- **Intelligent TOC Detection**: Detects Table of Contents sections using:
  - Deterministic rules (e.g., "Table of Contents" heading, known filenames)
  - Weighted scoring for ambiguous cases
  - Conservative defaults to avoid false positives
- **Recursive Inlining**: Automatically follows and inlines linked Markdown files
- **Anchor Collision Prevention**: Rewrites heading anchors with unique IDs to avoid conflicts
- **Cycle Detection**: Prevents infinite loops by tracking visited files
- **Remote Fetching**: Optional support for inlining remote files (opt-in with `--follow-remote`)
- **Configurable Behavior**: Fine-tune detection thresholds and inlining behavior

## Installation

```bash
opam install markdown_monolith
```

Or build from source:

```bash
git clone <repository-url>
cd markdown_monolith
opam install . --deps-only
dune build
dune install
```

## Usage

### Basic Usage

```bash
markdown_monolith input.md -o output.md
```

### CLI Options

- `INPUT`: Input markdown file path (required)
- `-o, --output OUTPUT`: Output path (default: stdout)
- `--follow-remote`: Enable fetching remote links (default: off)
- `--force-inline`: Force inlining of detected link lists
- `--force-skip`: Skip inlining for given files
- `--score-threshold FLOAT`: Override TOC detection score threshold (default: 0.75)
- `--min-links INT`: Minimum links to consider as TOC (default: 3)

### Examples

**Basic inlining:**
```bash
markdown_monolith main.md -o monolith.md
```

**Enable remote fetching:**
```bash
markdown_monolith main.md --follow-remote -o output.md
```

**Adjust detection sensitivity:**
```bash
markdown_monolith main.md --score-threshold 0.6 --min-links 2 -o output.md
```

## Library API

```ocaml
open Monolith

(* Configuration *)
let config = {
  default_config with
  follow_remote = true;
  max_depth = 5;
}

(* Process a file *)
match monolith_of_file ~config "input.md" with
| Ok output -> print_endline output
| Error msg -> prerr_endline ("Error: " ^ msg)

(* Detect if content is a TOC *)
let is_toc = detect_toc ~config "# Table of Contents\n\n- [Link](file.md)"
```

## TOC Detection

The library uses a multi-stage approach to detect Table of Contents:

### Deterministic Rules (Always Apply)
- Frontmatter key `monolith.inline_toc`
- Known filenames: `SUMMARY.md`, `_sidebar.md`, `TOC.md`
- Heading "Table of Contents" immediately followed by a link list
- HTML `<nav>` blocks with anchors

### Weighted Signals (Scored)
- **Heading Indicator** (25%): Presence of TOC-related heading
- **Contiguous Link List** (30%): Number of consecutive list items with links
- **Link Item Ratio** (20%): Proportion of list items containing links
- **Internal Links Ratio** (15%): Proportion of internal vs. external links
- **Short Link Text** (5%): Proportion of links with concise labels
- **Nav HTML** (5%): Presence of HTML navigation elements

A combined score ≥ 0.75 triggers inlining (configurable).

## Architecture

The implementation follows these design principles:

1. **AST-First**: All markdown processing operates on the Omd AST, not string manipulation
2. **Conservative Defaults**: Errs on the side of not inlining to avoid false positives
3. **Cycle Prevention**: Hash-set based deduplication prevents infinite loops
4. **Anchor Safety**: Unique ID prefixes prevent heading anchor collisions
5. **Opt-in Remote**: Remote fetching requires explicit `--follow-remote` flag

## Development

### Build
```bash
dune build
```

### Test
```bash
dune runtest
```

### Clean
```bash
dune clean
```

## Dependencies

- `omd` (>= 2.0): Markdown parsing
- `cmdliner`: CLI argument parsing
- `lwt`: Asynchronous I/O
- `cohttp-lwt-unix`: HTTP client for remote fetching

## License

See LICENSE file.

## Contributing

Contributions are welcome! Please ensure:
- Tests pass (`dune runtest`)
- Code follows existing style
- New features include tests
