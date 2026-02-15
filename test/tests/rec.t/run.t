Monolithize the Recursive Tests - with normal bullets
  $ markdown_monolith index.md
  # TOC
  
  Here is some stuff
  
  # First Link Page
  
  Content for first link.
  
  # Second Link Page
  
  Content for second link.
  
  # Sub Link 1 Page
  
  # Sub Link 2 Page
  
  # Sub Sub Link 1 Page
  
  # Third Link Page
  
  Okay but this one has more to it\!
  
  # Item 1 Page
  
  Some content for item 1.
  
  - Here is a list of stuff
  - But don't worry, since its not links it should stick around
  
  # Item 2
  
  Some content for item 2.
  
  
  
  Okay and stuff can come after it too\!
  
  [Final Link](final_link.md)
  
  Note, that link should not be processed.

Now do it with the remote version
  $ markdown_monolith --allow-remote https://raw.githubusercontent.com/Durbatuluk1701/markdown_monolith/refs/heads/main/test/tests/rec.t/index.md
  # TOC
  
  Here is some stuff
  
  # First Link Page
  
  Content for first link.
  
  # Second Link Page
  
  Content for second link.
  
  # Sub Link 1 Page
  
  # Sub Link 2 Page
  
  # Sub Sub Link 1 Page
  
  # Third Link Page
  
  Okay but this one has more to it\!
  
  # Item 1 Page
  
  Some content for item 1.
  
  - Here is a list of stuff
  - But don't worry, since its not links it should stick around
  
  # Item 2
  
  Some content for item 2.
  
  
  
  Okay and stuff can come after it too\!
  
  [Final Link](https://raw.githubusercontent.com/Durbatuluk1701/markdown_monolith/refs/heads/main/test/tests/rec.t/final_link.md)
  
  Note, that link should not be processed.
