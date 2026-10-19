#!/bin/sh
# Builds AMD's FidelityFX runtime (amd_fidelityfx_vk) for macOS arm64 from the FidelityFX SDK 1.1.4,
# producing libamd_fidelityfx_vk.dylib for Vulkan-on-MoltenVK hosts. MIT, like the SDK.
set -e
cd "$(dirname "$0")"

SDK_VERSION=1.1.4
SDK_DIR=FidelityFX-SDK

command -v glslangValidator >/dev/null || { echo "brew install glslang"; exit 1; }
command -v cmake >/dev/null || { echo "brew install cmake ninja"; exit 1; }

[ -d "$SDK_DIR" ] || git clone --depth 1 --branch "v$SDK_VERSION" \
    https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK.git

cd "$SDK_DIR"
if git apply --check ../patches/*.patch 2>/dev/null; then
    git apply ../patches/*.patch
    echo "patched the SDK sources"
else
    echo "patch(es) already applied"
fi

echo "== shader compiler tool =="
# CMAKE_POLICY_VERSION_MINIMUM: the vendored tiny-process-library declares CMake 2.8, which CMake 4 removed.
cmake -S sdk/tools/ffx_shader_compiler -B sdk/tools/ffx_shader_compiler/build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_HOME_DIRECTORY="$PWD/sdk/tools/ffx_shader_compiler" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build sdk/tools/ffx_shader_compiler/build

export FFX_SC_EXECUTABLE="$PWD/sdk/tools/ffx_shader_compiler/bin/FidelityFX_SC"

echo "== amd_fidelityfx_vk =="
cmake -S ffx-api -B ffx-api/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DFFX_API_BACKEND=VK_X64 -DCMAKE_HOME_DIRECTORY="$PWD/ffx-api" \
    -DCMAKE_PREFIX_PATH="$(brew --prefix)" -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build ffx-api/build

cd ..
mkdir -p lib
cp "$SDK_DIR/ffx-api/build/libamd_fidelityfx_vk.dylib" lib/
echo
echo "done: $(pwd)/lib/libamd_fidelityfx_vk.dylib"
