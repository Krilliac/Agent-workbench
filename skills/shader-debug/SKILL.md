---
name: shader-debug
description: "HLSL / SPIR-V / GLSL shader debugging with RenderDoc, PIX for Windows, and NSight. TRIGGER when the user says 'shader broken', 'pixel is black', 'wrong color output', 'RenderDoc capture', 'PIX', 'why isn''t this uniform binding', 'root signature mismatch', 'SPIR-V validation error', 'cross-compile broke my shader'. DO NOT TRIGGER for C++ compile errors involving shader headers, or non-shader graphics issues like state leaks. Covers RenderDoc pixel history, PIX GPU capture, SPIRV-Cross gotchas, D3D12 root sig debugging, and common HLSL to SPIR-V bugs that break cross-platform builds."
---

# shader-debug

## Tool choice
- **RenderDoc** default: free, D3D11/12/Vulkan/GL. Great pixel history + shader edit-and-reload.
- **PIX for Windows**: best for D3D12 root sig + PSO debugging.
- **spirv-val / spirv-cross**: HLSL -> SPIR-V pipeline lifesavers.

## RenderDoc flow
1. Launch injected. F12 during broken frame.
2. Select misbehaving draw in event browser.
3. Right-click pixel -> History (which event wrote wrong value).
4. Right-click pixel -> Debug Pixel (step through PS with locals).

## HLSL bugs that only fail on SPIR-V
- `register(t0, space0)` vs `register(u0, space0)` on Vulkan -- distinct spaces needed.
- HLSL `float3` = 16 B in CB, SPIR-V = 12 B unless `[[vk::layout(std140)]]`.
- Semantic-based binding non-existent on Vulkan -- `[[vk::location(N)]]` on inputs + outputs.
- `SV_TARGET` count: HLSL infers; SPIR-V requires explicit `[[vk::location(N)]]`.

Cross-compile: `dxc -T ps_6_5 -spirv -fspv-target-env=vulkan1.2 -Fo out.spv in.hlsl`. Then `spirv-val out.spv`.

## D3D12 root sig
- `ID3D12Debug1::SetEnableGPUBasedValidation(TRUE)` in dev.
- CBV size must be `sizeof(CB) rounded to 256 B`.
- Descriptor heap must be `SHADER_VISIBLE`.
- Root params > 64 DWORDs -> use descriptor tables.

## Capture size
Bind a break-on-key; capture only the broken frame.

## Method
1. Reproduce in minimal frame; distinctive clear color.
2. Capture.
3. Pixel history first (usually names the draw).
4. Shader-debug the PS; compare expected vs actual binding.
5. Cross-compile bugs: run spirv-val, diff DXIL vs SPIR-V disassembly.