Monolithize the Failed Reconcile Tests - Stdout
  $ markdown_monolith index.md 2> /dev/null
  # Failed Reconcile Test
  
  This test will look for another file to inline, but that file does not have a header. The expected behavior is that a warning is printed, but the inlining proceeds without link reconciliation.
  
  # File1 With A Header
  
  This file has a header, so link reconciliation should work properly.
  
  This is file2. It has no header, so link reconciliation should fail here.
  
  There really isnt a good way to link back to this just text blob without some header!!\!
  
  
  Then later, we reference back to [File1\_WithHeader](#file1-with-a-header) which should work, and to [File2\_NoHeader](./file2_noheader.md) which should not work since that file has no header.

Monolithize the Failed Reconcile Tests - Stderr
  $ markdown_monolith index.md 1> /dev/null
  Warning: No header found in document at path file2_noheader.md. Inlining will proceed without link reconciliation.

Monolithize the Failed Reconcile Tests - Force Reconciliation (should fail)
  $ markdown_monolith --force-reconciliation index.md 
  markdown_monolith: monolith failed: Warning: No header found in document at
                     path file2_noheader.md.
  [124]
