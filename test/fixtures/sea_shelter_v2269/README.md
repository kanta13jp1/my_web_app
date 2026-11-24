# Frozen production compatibility fixture

Exact, unmodified source from published1.0.2269, commit `fbc5274036fc5d9ff748916792a46e5e9afdf76b` (same feature blobs as mergedPR5936/main `3dd1988b8f3875498d95ce94b8255a40cd17b380`). Own repository code; no third-party game material.

- model.mjs Git blob: `6ccd76f091317327b3d4472f0355119c188f2302`
- farm.mjs Git blob: `440f60406b88de0699462107f85f270a2b410ebc`

Do not format or update these two frozen files. The storage test verifies their exact hashes, imports their real decoder/actions, and checks that an old-version round trip preserves warehouse metadata/reserves while keeping the old numeric core within its99,999 bounds. This is compatibility evidence, not a reimplementation of the new code.
