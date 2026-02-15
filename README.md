# markdown_monolith

[![Documentation](https://img.shields.io/badge/docs-github.io-blue)](https://durbatuluk1701.github.io/markdown_monolith/)
[![OCaml](https://img.shields.io/badge/OCaml-4.14+-orange.svg)](https://ocaml.org/)
[![License](https://img.shields.io/badge/license-see%20LICENSE-lightgrey)](./LICENSE)

An OCaml library and CLI tool to produce a single monolithic Markdown file by parsing with Cmarkit, detecting navigational TOC-like link lists, recursively inlining referenced Markdown files, and automatically reconciling relative paths for non-inlined resources.

**[📚 View Full API Documentation](https://durbatuluk1701.github.io/markdown_monolith/)**

## Installation

```bash
opam install markdown_monolith
```

## Documentation

**Full API documentation is available at: [https://durbatuluk1701.github.io/markdown_monolith/](https://durbatuluk1701.github.io/markdown_monolith/)**

The documentation includes:
- Comprehensive API reference for all modules and functions
- Detailed configuration options with examples
- Usage patterns and best practices
- Limitations and security considerations

You can also build the documentation locally:
```bash
dune build @doc
# View at _build/default/_doc/_html/markdown_monolith/index.html
```

## Usage

### Basic Usage

```bash
markdown_monolith input.md -o output.md
```

### Examples

**Basic inlining:**
```bash
markdown_monolith main.md -o monolith.md
```

**Enable remote fetching (use with caution):**
```bash
markdown_monolith main.md --allow-remote -o output.md
```

**Control recursion depth:**
```bash
markdown_monolith main.md --max-depth 5 -o output.md
```

## Library API

For detailed API documentation, see [https://durbatuluk1701.github.io/markdown_monolith/](https://durbatuluk1701.github.io/markdown_monolith/)

```ocaml
open Markdown_monolith

(* Create custom configuration *)
let config = {
  Monolith.default_config with
  allow_remote = false;  (* Keep remote fetching disabled for security *)
  max_depth = 5;         (* Limit recursion depth *)
  dedupe = true;         (* Prevent duplicate inlining *)
}

(* Process a file *)
match Monolith.monolith_of_file ~config "input.md" with
| Ok doc -> 
    let output = Cmarkit_commonmark.of_doc doc in
    print_endline output
| Error msg -> 
    prerr_endline ("Error: " ^ msg)
```

### Key Functions

- `monolith_of_file`: Main function to process a markdown file into a monolithic document

See the [full API documentation](https://durbatuluk1701.github.io/markdown_monolith/markdown_monolith/Monolith/) for complete details.

## Dependencies

- `cmarkit`: Modern CommonMark parser and renderer
- `cmdliner`: CLI argument parsing
- `lwt`: Asynchronous I/O
- `cohttp-lwt-unix` (>= 5.0): HTTP client for remote fetching
- `lwt_ssl` (>= 1.2.0): SSL/TLS support for HTTPS

## License

See LICENSE file.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

For bug reports and feature requests, please use the [GitHub issue tracker](https://github.com/Durbatuluk1701/markdown_monolith/issues).
