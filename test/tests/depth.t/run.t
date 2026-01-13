Monolithize the Depth Tests - Default Depth (should fail)
  $ markdown_monolith index.md 2>&1 | sed -E '/^\s+(Called|Raised).+/d'
  markdown_monolith: monolith-ification failed: Maximum depth 10 exceeded at
                     path page11.md

Monolithize the Dedupe Tests - Duplication Allowed
  $ markdown_monolith --max-depth=11 index.md
  # Index
  
  This will start a super long chain (with depth 11) of inlined files.
  
  # Page 1:
  
  Page 1 Content.
  
  # Page 2:
  
  Page 2 Content.
  
  # Page 3:
  
  Page 3 Content.
  
  # Page 4:
  
  Page 4 Content.
  
  # Page 5:
  
  Page 5 Content.
  
  # Page 6:
  
  Page 6 Content.
  
  # Page 7:
  
  Page 7 Content.
  
  # Page 8:
  
  Page 8 Content.
  
  # Page 9:
  
  Page 9 Content.
  
  # Page 10:
  
  Page 10 Content.
  
  # Page 11:
  
  Page 11 Content.
  
  This is the final page!!\!
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  


















