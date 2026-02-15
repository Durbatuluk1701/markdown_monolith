Monolithize the with Up and Down movement
  $ markdown_monolith ./TOC.md
  # TOC
  
  Simple TOC
  
  # Nested
  
  This file references the [test file](./nested/test.txt). It needs to fix the path when this is monolithized.
  
  It also has a [sibling reference](./nested/sibling.txt) and points to [top level resource](./top_resource.json).
  
  # Another Nested
  
  This file has multiple link types:
  
  - Link to sibling: [sibling text](./nested/sibling.txt)
  - Link to parent dir resource: [top resource](./top_resource.json)
  - Link to test file: [test](./nested/test.txt)
  - Link going up and down: [back to test](./nested/test.txt)
  
  
  # Deeply Nested
  
  Links from deep in the hierarchy:
  
  - Link to grandparent: [top resource](./top_resource.json)
  - Link to parent dir: [test file](./nested/test.txt)
  - Link to uncle file: [sibling](./nested/sibling.txt)
  
  
  # Test Unchanged Links
  
  This document has a link that references the correct path already: [test](./nested/test.txt).
  
  This shouldn't change because it's already correct relative to TOC.md when inlined.
  

