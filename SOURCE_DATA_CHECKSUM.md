# Simulated source-data checksum

The 19,000 files under `Simulated Data/` are immutable source data. Their
pre-migration and post-migration Git blob multisets are identical.

The reproducibility validator reads the content-addressed blob hash for every
file from the Git index, sorts the 19,000 hashes, joins them in memory with LF
separators, and hashes that string. This avoids platform-specific CRLF/LF
checkout conversion. The registered aggregate MD5 is:

`26c5f43f34cb45e13481fc8d90d339d8`

Changing a versioned source file causes `scripts/validate_reproducibility.R` to
fail. File and directory renames do not change this content-only checksum.
