(** {1 Markdown Monolith}

    An OCaml library for producing a single, monolithic Markdown document by 
    intelligently parsing, detecting, and inlining linked Markdown files.

    This library provides AST-based processing using the {{:https://erratique.ch/software/cmarkit}Cmarkit} 
    library to parse and traverse Markdown documents. It can automatically detect 
    Table of Contents (TOC) sections and recursively inline referenced files, making 
    it ideal for generating comprehensive documentation from distributed source files.

    {2 Key Features}

    {ul
      {- {b Intelligent TOC Detection}: Automatically identifies lists of links that 
         function as navigation or table of contents}
      {- {b Recursive Inlining}: Follows and inlines linked Markdown files 
         automatically, preserving document structure}
      {- {b Cycle Detection}: Prevents infinite loops through duplicate detection 
         when [dedupe] is enabled}
      {- {b Anchor Rewriting}: Converts file links to anchor links in the final 
         monolithic document}
      {- {b Remote Fetching}: Optional support for inlining remote HTTP/HTTPS files 
         (disabled by default for security)}
      {- {b Depth Control}: Configurable maximum recursion depth to prevent runaway 
         inlining}
    }

    {2 Limitations}

    {ul
      {- {b Link Pattern Detection}: Only processes links that appear in list items 
         with bullet-like prefixes ({{!bullet_ish_prefix}see bullet patterns}). 
         Links in regular paragraphs are {e not} inlined.}
      {- {b File System Access}: Cannot inline files that are not accessible via 
         local file paths or HTTP/HTTPS URLs when [allow_remote] is disabled}
      {- {b CommonMark Only}: Only processes valid CommonMark/Markdown syntax. 
         Malformed documents may produce unexpected results}
      {- {b No Circular Reference Resolution}: While cycles are detected when 
         [dedupe] is enabled, the library does not attempt to intelligently resolve 
         or restructure circular references}
      {- {b Depth Limit}: Recursion stops at [max_depth], which may leave some 
         nested files un-inlined if the depth limit is too restrictive}
      {- {b No Partial Inlining}: Once a file is marked as inlined (when [dedupe] 
         is true), subsequent references create placeholder text and a {e backreference}
         to the original inlined file, rather than duplicating content}
    }

    {2 Usage Example}

    {[
      open Markdown_monolith

      (* Create custom configuration *)
      let config = {
        default_config with
        allow_remote = false;  (* Keep remote fetching disabled for security *)
        max_depth = 5;         (* Limit recursion depth *)
        dedupe = true;         (* Prevent duplicate inlining *)
      } in

      (* Process a file *)
      match monolith_of_file ~config "index.md" with
      | Ok doc -> 
          let output = Cmarkit_commonmark.of_doc doc in
          print_endline output
      | Error msg -> 
          prerr_endline ("Error: " ^ msg)
    ]}

    @since 0.1.0
*)

(** {1 Configuration} *)

type config =
  { allow_remote : bool
    (** If [true], follow and inline remote links (HTTP/HTTPS URLs). 
        
        {b Default}: [false]
        
        {b Warning}: Enabling this option may introduce security risks and excessive 
        network usage. Remote content is fetched synchronously and there are no 
        built-in rate limits or timeouts beyond the HTTP client defaults. Only 
        enable this if you trust the remote sources.
        
        {b Behavior}: When [false], attempting to inline a remote link will result 
        in an error or the link being skipped.
    *)
  ; max_depth : int
    (** Maximum recursion depth for inlining files.
    
        {b Default}: [10]
        
        {b Constraint}: Must be positive. Setting this to a very high value may 
        cause stack overflow or excessive processing time.
        
        {b Behavior}: When the depth limit is reached during recursion, the 
        processing fails with an error indicating the maximum depth was exceeded.
        
        {b Example}: A [max_depth] of [3] allows the root document (depth 0) to 
        inline files (depth 1), which can inline files (depth 2), which can inline 
        files (depth 3), but no deeper.
    *)
  ; dedupe : bool
    (** If [true], do not inline the same file more than once.
    
        {b Default}: [true]
        
        {b Behavior}: When enabled, maintains an internal map of previously inlined 
        file paths. If a file is encountered again, instead of inlining it a second 
        time, a placeholder text "Duplicate Reference to: [link]" is inserted.
        
        {b Use Case}: Essential for preventing infinite loops in documents with 
        circular references or shared sub-documents referenced from multiple places.
        
        {b Trade-off}: While this prevents duplication, it means repeated content 
        must be accessed via anchor links in the final document rather than being 
        present at multiple locations.
    *)
  ; strict_commonmark : bool
    (** If [true], enforce strict CommonMark parsing rules.
    
        {b Default}: [false]
        
        {b Behavior}: Passed directly to the Cmarkit parser. When [true], the 
        parser follows the CommonMark specification strictly. When [false], some 
        common Markdown extensions may be accepted.
        
        {b Recommendation}: Use [true] for maximum compatibility and predictable 
        parsing behavior. In particular refer to the {{:https://erratique.ch/software/cmarkit/doc/Cmarkit/index.html#extensions}Cmarkit documentation} and {{:https://spec.commonmark.org/}Commonmark Spec} for details.
    *)
  ; add_newlines : bool
    (** If [true], add blank lines between inlined content blocks.
    
        {b Default}: [true]
        
        {b Behavior}: When a file is inlined, this option controls whether a blank 
        line is inserted after the inlined content. This helps visually separate 
        inlined sections in the final output.
        
        {b Recommendation}: Keep enabled for better readability of the generated 
        monolithic document.
    *)
  }

(** The default configuration with safe, conservative settings.

    Default values:
    - [allow_remote = false] — Remote fetching disabled for security
    - [max_depth = 10] — Reasonable recursion limit
    - [dedupe = true] — Prevent infinite loops
    - [strict_commonmark = false] — Accept common Markdown extensions
    - [add_newlines = true] — Better visual separation

    @since 0.1.0
*)
val default_config : config

(** {1 Utility Functions} *)

(** [bullet_ish_prefix prefix] determines if a string looks like a list item prefix. This is important for identifying links that are part of lists (e.g., TOCs) versus regular paragraphs.
    
    Returns [true] if [prefix] matches one of the following patterns:
    {ul
      {- Unordered list markers: [*], [-], [+]}
      {- Ordered list markers: Any sequence of digits and periods/parentheses like 
         [1.], [1)], [1.2.], [1.2.3), etc.]}
    }
    
    Returns [false] otherwise.
    
    {b Whitespace}: The function automatically trims leading and trailing whitespace 
    from [prefix] before matching.
    
    {b Example Usage}:
    {[
      bullet_ish_prefix "  * " ;;  (* true *)
      bullet_ish_prefix "1." ;;    (* true *)
      bullet_ish_prefix "1.2.3" ;; (* true *)
      bullet_ish_prefix "abc" ;;   (* false *)
      bullet_ish_prefix "" ;;      (* false *)
    ]}
    
    {b Critical for Inlining}: This function determines which links are eligible for 
    inlining. Only links that appear in paragraphs with bullet-ish prefixes (within 
    list items) are considered for recursive inlining.
    
    @param prefix The string to test
    @return [true] if it matches a bullet or numbered list pattern, [false] otherwise
    @since 0.1.0
*)
val bullet_ish_prefix : string -> bool

(** {1 Main API} *)

(** [monolith_of_file ?config filepath] produces a monolithic Markdown document.
    
    Starting from the file at [filepath], this function:
    {ol
      {- Parses the Markdown content into a Cmarkit AST}
      {- Traverses the AST looking for lists of links (TOC-like structures)}
      {- Recursively inlines the content of linked files}
      {- Rewrites file links to anchor links pointing to inlined content}
      {- Returns the final monolithic document as a Cmarkit AST}
    }
    
    {b Link Detection}: The function only processes links that appear in list items 
    with bullet-like prefixes. Links in regular paragraphs are {e not} processed. 
    See {{!bullet_ish_prefix}bullet_ish_prefix} for supported patterns.
    
    {b Path Resolution}: File paths are resolved relative to the current document 
    being processed. Absolute paths and URLs are supported based on configuration.
    
    {b Return Value}: Returns a Cmarkit AST ([Cmarkit.Doc.t]) on success, or an 
    error message on failure. To convert the AST to a string, use:
    {[
      match monolith_of_file "index.md" with
      | Ok doc -> Cmarkit_commonmark.of_doc doc
      | Error msg -> "Error: " ^ msg
    ]}
    
    {b Error Conditions}:
    {ul
      {- Maximum depth exceeded (when recursion goes beyond [config.max_depth])}
      {- File not found or not readable}
      {- Remote fetch disabled but remote URL encountered (when [allow_remote = false])}
      {- Network errors (when fetching remote content)}
      {- Malformed URIs or unsupported URI schemes}
    }
    
    {b Performance Considerations}:
    {ul
      {- Processing time scales with the number of files and their sizes}
      {- Remote fetches are synchronous and can be slow}
      {- Deep nesting (high [max_depth]) may consume significant stack space}
      {- Large numbers of cross-references may impact memory usage}
    }
    
    {b Side Effects}: 
    {ul
      {- File system reads for local files}
      {- Network requests for remote URLs (when [allow_remote = true])}
      {- No modifications are made to source files}
    }
    
    @param config Optional configuration (defaults to {{!default_config}default_config})
    @param filepath Path to the root Markdown file (local file path or file:// URI)
    @return [Ok doc] with the monolithic Cmarkit document, or [Error msg] with an error description
    
    @since 0.1.0
*)
val monolith_of_file : ?config:config -> string -> (Cmarkit.Doc.t, string) result
