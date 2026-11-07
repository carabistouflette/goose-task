# Releasing

The first experimental release is `v0.1.0-alpha.1`. Before creating its tag:

1. Independently review the complete source and publication changes.
2. Verify GitHub private vulnerability reporting is enabled and the README
   quickstart works from a standalone clone.
3. Require all GCC/Clang CI checks on the exact release commit to succeed.
   Do not substitute a different source tree or incomplete run.
4. Check the dated changelog, Apache-2.0 license, source/compiler pins and
   benchmark limitations. Preserve initial local-validation evidence unchanged.
5. Create the tag once, verify its full commit through the public API, and
   publish a prerelease that documents the experimental interface and limits.

A release tag identifies source; it is not a signature or a promise of hosted
release immutability. Never move a published tag. Registry publication, consumer
adoption and catalog registration are separate validated changes.
