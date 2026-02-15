Monolithize the Basic Tests
  $ markdown_monolith ./TOC.md
  # Table of Contents
  
  # Introduction
  
  Intro content here.
  
  ## Getting Started
  
  Some getting started information.
  
  - Point one
  - Point two
    
  
  
  # Outro
  
  Outro content here.
  
  
Now do the remote version
  $ markdown_monolith --allow-remote https://raw.githubusercontent.com/Durbatuluk1701/markdown_monolith/refs/heads/main/test/tests/basic.t/TOC.md
  # Table of Contents
  
  # Introduction
  
  Intro content here.
  
  ## Getting Started
  
  Some getting started information.
  
  - Point one
  - Point two
    
  
  
  # Outro
  
  Outro content here.
  
  
Monolithize the Basic Tests - with no newlines
  $ markdown_monolith --add-newlines=false ./TOC.md
  # Table of Contents
  
  # Introduction
  
  Intro content here.
  
  ## Getting Started
  
  Some getting started information.
  
  - Point one
  - Point two
    
  
  # Outro
  
  Outro content here.
  

Help Page
  $ markdown_monolith --help=plain
  NAME
         markdown_monolith - Produce a monolithic Markdown file by inlining
         linked files and reconciling paths.
  
  SYNOPSIS
         markdown_monolith [OPTION]… FILE
  
  ARGUMENTS
         FILE (required)
             FILE is the file to read from. (Note a remote file (i.e.
             "https://..." can be provided here as well assuming
             `--allow-remote` is enabled.)
  
  OPTIONS
         --add-newlines=BOOL (absent=true)
             Add newlines between inlined content
  
         --allow-remote
             Enable fetching remote links
  
         --dedupe=BOOL (absent=true)
             Enable deduplication of files
  
         --force-reconciliation
             Force link reconciliation; error if headers missing
  
         --max-depth=INT (absent=10)
             Maximum recursion depth (default: 10)
  
         -o FILE, --output=FILE (absent='-')
             FILE is the file to write to. Use - for stdout
  
         --strict-commonmark
             Enable strict CommonMark parsing
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
  EXIT STATUS
         markdown_monolith exits with:
  
         0   on success.
  
         1   Writing output file failed.
  
         2   Monolithification failed.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
