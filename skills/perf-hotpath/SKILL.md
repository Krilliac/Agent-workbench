---
name: perf-hotpath
description: Analyze and optimize C++ hot paths in a game engine -- cache coherency, false sharing, SIMD, branch prediction, allocation patterns. TRIGGER when the user says "why is this slow", "optimize the render loop", "hot path", "cache miss", "false sharing", "SIMD this", "AVX2", "vectorize", "profile with Superluminal", "VTune says", "frame time spiked". DO NOT TRIGGER for I/O bottlenecks, GC/allocator issues alone (use memory-hunt), or algorithmic complexity (that's a design conversation). Focused on tight-loop per-frame code -- concrete recipes for Superluminal, VTune, WPA, plus callouts for common footguns.
---

# perf-hotpath

## Measure first

- **Superluminal**: fastest on Windows. Attach -> Capture 5s -> flame graph -> top-3 self-time.
- **VTune**: `vtune -collect uarch-exploration -knob sampling-mode=hw -- the engine.exe` for cache miss / mispred / port pressure.
- **WPA**: `wpr -start CPU -filemode`, `wpr -stop out.etl` for OS-level context switches.

## Cache coherency
- Hot data `vector<T>`, not `vector<T*>`.
- `T` <= 64 B for primary access, else SoA-split.
- Per-thread scratch `alignas(64)`; false sharing manifests as inexplicable 2-3x slowdown when adding threads.
- Pad seqnum atomics: `struct alignas(64) FrameSlot { atomic<u64> seq; char _pad[56]; };`

## Vectorization blockers
`/arch:AVX2 /Qvec-report:2` on MSVC (or `-Rpass=loop-vectorize` on clang-cl). Common on the engine:
- Aliased pointers -- `__restrict__`.
- Reduction across a member -- hoist into local `float acc = 0`.
- Non-contiguous -- SoA, not AoS.
- Fn call in body -- inline / `[[gnu::always_inline]]`.

## Branch prediction
- Sort input by predicate before loop.
- `[[likely]]` / `[[unlikely]]` respected on MSVC 19.3+.
- Table lookup > deep if/else for polymorphic dispatch.

## Allocation rule
Zero heap alloc per frame. Frame arena `linear_allocator` per thread reset every frame. Small-buffer optimizations (`boost::small_vector`, `absl::InlinedVector`).

## Thread-safety of hot data
Either immutable-after-launch, or double-buffered (game writes slot N, render reads slot N-1). Never take a lock in the render loop.

## the engine hot paths
- ECS `archetype_query` iteration (SoA already; ensure query returns components w/o indirection).
- Skel anim matrix palette (mandatory SIMD, `float4x4[]`).
- Frustum culling (SIMD 4-plane x 4-object, unroll 4).

## Report
Before/after ns per call, capture method, uarch counter delta, diff, assumptions.