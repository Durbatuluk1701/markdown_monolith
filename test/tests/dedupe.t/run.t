Monolithize the Dedupe Tests - Duplication Removed
  $ markdown_monolith index.md
  # Dedupe Test
  
  Here are the top level files
  # Page 1
  
  This is page 1.
  
  # Page 3
  
  Here is some more content for page 3.
  
  
  # Page 2
  
  This is page 2 of the dedupe test.
  
  Duplicate Reference to: [Go to Page 3](#page-3)
  
  
  Note: they should diamond onto page 3, but it should only be inlined once.

Monolithize the Dedupe Tests - Duplication Allowed
  $ markdown_monolith --dedupe=false index.md
  # Dedupe Test
  
  Here are the top level files
  # Page 1
  
  This is page 1.
  
  # Page 3
  
  Here is some more content for page 3.
  
  
  # Page 2
  
  This is page 2 of the dedupe test.
  
  # Page 3
  
  Here is some more content for page 3.
  
  
  
  Note: they should diamond onto page 3, but it should only be inlined once.
