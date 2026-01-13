# Failed Reconcile Test

This test will look for another file to inline, but that file does not have a header. The expected behavior is that a warning is printed, but the inlining proceeds without link reconciliation.

- [File1_WithHeader](./file1_withheader.md)
- [File2_NoHeader](./file2_noheader.md)

Then later, we reference back to [File1_WithHeader](./file1_withheader.md) which should work, and to [File2_NoHeader](./file2_noheader.md) which should not work since that file has no header.