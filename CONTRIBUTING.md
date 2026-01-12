# Contributing to markdown_monolith

Thank you for your interest in contributing to markdown_monolith! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Documentation](#documentation)
- [Submitting Changes](#submitting-changes)
- [Style Guide](#style-guide)

## Code of Conduct

This project adheres to a code of conduct that emphasizes respect, professionalism, and inclusivity. By participating, you are expected to uphold these standards.

## Getting Started

### Prerequisites

- OCaml 4.14 or later
- opam (OCaml package manager)
- dune build system
- Git

### Setting Up Your Development Environment

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/markdown_monolith.git
   cd markdown_monolith
   ```

3. Install dependencies:
   ```bash
   opam install . --deps-only --with-test --with-doc
   ```

4. Build the project:
   ```bash
   dune build
   ```

5. Run tests to verify your setup:
   ```bash
   dune runtest
   ```

## Development Workflow

### Branch Strategy

- `main` - stable, production-ready code
- Feature branches - `feature/description` for new features
- Bug fix branches - `fix/description` for bug fixes
- Documentation branches - `docs/description` for documentation updates

### Making Changes

1. Create a new branch for your work:
   ```bash
   git checkout -b feature/my-new-feature
   ```

2. Make your changes, following the [Style Guide](#style-guide)

3. Add tests for new functionality

4. Ensure all tests pass:
   ```bash
   dune runtest
   ```

5. Build documentation and verify it looks correct:
   ```bash
   dune build @doc
   # Open _build/default/_doc/_html/markdown_monolith/index.html
   ```

6. Commit your changes with clear, descriptive commit messages:
   ```bash
   git commit -m "Add feature: description of feature"
   ```

## Testing

### Running Tests

```bash
# Run all tests
dune runtest

# Run tests and show output
dune runtest --force --no-buffer

# Run specific test
dune exec -- test/tests/basic.t/run.t
```

### Writing Tests

Tests are located in `test/tests/` and use the Cram test format (`.t` files).

Example test structure:
```bash
  $ markdown_monolith input.md -o output.md
  # Expected output here
```

When adding new features:
1. Create a new directory under `test/tests/` with a descriptive name
2. Add test input files (`.md` files)
3. Create a `run.t` file with test commands and expected output
4. Update `test/dune` if needed

## Documentation

### Code Documentation

All public functions and types should have OCamldoc comments:

```ocaml
(** [function_name arg1 arg2] does something useful.
    
    {b Parameters}:
    - [arg1]: Description of first argument
    - [arg2]: Description of second argument
    
    {b Returns}: Description of return value
    
    {b Example}:
    {[
      let result = function_name "value1" 42 ;;
    ]}
    
    @param arg1 First argument description
    @param arg2 Second argument description
    @return Return value description
    @since 0.1.0
*)
val function_name : string -> int -> result
```

### Building Documentation

```bash
# Build HTML documentation
dune build @doc

# View locally
open _build/default/_doc/_html/markdown_monolith/index.html
# Or on Linux:
xdg-open _build/default/_doc/_html/markdown_monolith/index.html
```

### Documentation Guidelines

- Use complete sentences ending with periods
- Include examples for complex functions
- Document both successful and error cases
- Highlight security considerations with `{b Warning}`
- Document limitations and edge cases
- Cross-reference related functions using `{{!identifier}text}`

## Submitting Changes

### Pull Request Process

1. Update the README.md with details of changes if applicable
2. Update the documentation for any API changes
3. Add tests that verify your changes work correctly
4. Ensure all tests pass: `dune runtest`
5. Ensure documentation builds without warnings: `dune build @doc`
6. Push your changes to your fork:
   ```bash
   git push origin feature/my-new-feature
   ```
7. Open a Pull Request on GitHub

### Pull Request Guidelines

- **Title**: Use a clear, descriptive title
- **Description**: Explain what changes you made and why
- **Testing**: Describe how you tested the changes
- **Related Issues**: Link to any related issues (e.g., "Fixes #123")
- **Breaking Changes**: Clearly mark any breaking changes

Example PR template:
```markdown
## Description
Brief description of changes

## Motivation
Why are these changes needed?

## Changes
- Change 1
- Change 2

## Testing
How were these changes tested?

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] All tests pass
- [ ] No new warnings
```

## Style Guide

### OCaml Code Style

Follow the project's existing code style:

1. **Indentation**: 2 spaces (no tabs)
2. **Line length**: Aim for 80-100 characters, max 120
3. **Naming conventions**:
   - `snake_case` for functions, variables, and modules
   - `CamelCase` for module types and functors
   - `lowercase` for type names
4. **Pattern matching**: Align `|` characters
5. **Comments**: Use `(* *)` for regular comments, `(** *)` for documentation

Example:
```ocaml
let process_markdown_file
      ?(config = default_config)
      ~input_path
      ~output_path
  =
  match read_file input_path with
  | Ok content ->
    let doc = parse_markdown content in
    process_document ~config doc
  | Error err ->
    Error (Printf.sprintf "Failed to read file: %s" err)
```

### Documentation Style

- Use standard OCamldoc formatting
- Include `@param`, `@return`, `@since` tags where appropriate
- Document exceptions that can be raised
- Provide examples for non-trivial functions
- Use proper markup: `[code]`, `{b bold}`, `{i italic}`, `{ul lists}`

### Commit Message Style

Follow conventional commits format:

```
type(scope): subject

body

footer
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `chore`: Maintenance tasks

Examples:
```
feat(parser): add support for nested lists

Implements recursive list parsing to handle multiple nesting levels.

Fixes #42
```

```
fix(cli): correct default output path handling

The CLI was not properly handling stdout when no output file was specified.
```

## Questions?

If you have questions:
- Check existing issues and discussions
- Open a new issue with the "question" label
- Reach out to maintainers

Thank you for contributing! 🎉
