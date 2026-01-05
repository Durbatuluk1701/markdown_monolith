Monolithize the Recursive Tests - with normal bullets
  $ markdown_monolith index.md
  # Nested Test
  
  This test checks that nested includes work correctly.
  
  # Nested
  
  # Double Nested File
  
  Here is a double nested file. It refers to the [other file](#other-file).
  
  # Back To Top File
  
  here is back to top file stuff
  
  
  
  
  
  This file refer up to the [other file](#other-file).
  
  # Other File
  
  This file has a BACK LINK back to [back to the nested file](#nested).
