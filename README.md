# fsr3-native-macos

AMD FSR 3.1 (`amd_fidelityfx_vk`) built natively for macOS / Apple Silicon, for Vulkan apps
running on MoltenVK. Believed to be the first FidelityFX-under-MoltenVK build anywhere.

Verified in [MeitouClient](https://github.com/VlcekM/MeitouClient) (a Kenshi engine
reimplementation) on an M1 Pro, macOS 15.1, MoltenVK 1.4.2: the game's existing `MEITOU_FFX_PATH`
integration loads the dylib and FSR 3.1 renders correctly (`fsr 3.1 1512x856` in the title bar,
FSR's passes visible in the GPU profiler).

Verdict on an M1 Pro: **correct but slower than the built-in TAA** — FSR's compute passes cost
~12 ms/frame through MoltenVK (dispatch/barrier translation overhead), vs a nearly-free TAA
resolve. On Apple Silicon, TAA remains the practical choice; this exists because FSR could not
even load on macOS before.

AMD ships the runtime only for Windows; the SDK's Vulkan backend, however, compiles its GLSL
shaders with glslang (not DXC), so the whole pipeline is buildable on macOS with modest patches.

## Build

Requirements: macOS arm64, Xcode, brew `glslang`, `vulkan-loader`, `cmake`, `ninja`.

```
./build.sh
# → lib/libamd_fidelityfx_vk.dylib
```

The script clones the SDK at v1.1.4, applies [patches/fidelityfx-sdk-macos.patch](patches/fidelityfx-sdk-macos.patch)
(22 files, all `#ifdef _WIN32`-shaped — no Windows behaviour change), builds the `ffx_sc` shader
compiler tool, pre-compiles all shader permutations, and links the dylib.

## Use

Set `MEITOU_FFX_PATH` to the dylib (or put it next to the executable) in any app integrating the
FidelityFX API (`ffxCreateContext`/`ffxDispatch`), and pick FSR. For MeitouClient also set
`MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1`. The game hands FFX its own MoltenVK device; the dylib
only needs the brew Vulkan loader present for `vkGetDeviceProcAddr`.

## What the patches touch

- `ffx_sc` tool: `wmain`→`main` shim, portable UTF-8/paths (`std::wstring_convert` is gone from
  libc++), HLSL/DXC branches excluded (the GLSL path never uses them), macOS `/bin/sh`
  **brace-expands `{0,1}`**, so permutation options arrive as duplicate `-D` defines ("Macro
  redefined") — they are re-merged into the brace form; and the glslang error parser built a
  string from an `npos` iterator (crashed on any shader error; MSVC tolerated it).
- Build: non-MSVC generator platform derivation, the Windows toolchain skipped, the prebuilt
  `FidelityFX_SC.exe`/`glslangValidator.exe` replaced by the locally built tool + brew glslang.
- Frame generation (frame interpolation) is excluded — its VK swapchain is Windows presentation
  integration; its 16 entry points are stubbed with graceful errors. Upscale paths are untouched.
- arm64 layout: private context buffers pack larger than the Windows-sized default
  (`FFX_SDK_DEFAULT_CONTEXT_SIZE` doubled; asserted in the components).
- `ffx_api.h`: `__declspec(dllexport)` → visibility attribute off Windows.

## Related

- [MeitouClient macOS port / PR](https://github.com/VlcekM/MeitouClient/pull/8) — integration and port report (docs/macos-port.md §9)
- [fsr4-native-macos](https://github.com/UzenUPoZiTiV4ik/fsr4-native-macos) — FSR 4 (neural) on Metal via CrossOver's DLSS hook; different layer, same community goal

Patches: MIT (matching the SDK's licence). AMD FidelityFX SDK is © AMD, MIT.
