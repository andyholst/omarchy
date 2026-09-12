#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command lua

MOCK_OMARCHY_DIR=""

cleanup() {
  if [[ -n $MOCK_OMARCHY_DIR && -d $MOCK_OMARCHY_DIR ]]; then
    rm -rf "$MOCK_OMARCHY_DIR"
  fi
}
trap cleanup EXIT

# Mock hardware detection commands. nvidia.lua constructs the path as
# paths.omarchy_path .. "/bin/omarchy-hw-*", so we create a temporary
# omarchy directory with a bin/ full of mock commands and point
# OMARCHY_PATH at it. We symlink the default/ directory from the repo
# so nvidia.lua can be dofile'd from the same OMARCHY_PATH.
mock_hw_commands() {
  local hybrid="$1"
  local gsp="$2"
  local without_gsp="$3"

  MOCK_OMARCHY_DIR=$(mktemp -d)
  mkdir -p "$MOCK_OMARCHY_DIR/bin"
  ln -s "$ROOT/default" "$MOCK_OMARCHY_DIR/default"

  for cmd in omarchy-hw-nvidia omarchy-hw-nvidia-gsp omarchy-hw-nvidia-without-gsp omarchy-hw-hybrid-gpu; do
    local want=no
    case "$cmd" in
      omarchy-hw-nvidia) want=yes ;;
      omarchy-hw-nvidia-gsp) want="$gsp" ;;
      omarchy-hw-nvidia-without-gsp) want="$without_gsp" ;;
      omarchy-hw-hybrid-gpu) want="$hybrid" ;;
    esac
    if [[ $want == "yes" ]]; then
      printf '#!/bin/bash\nexit 0\n' >"$MOCK_OMARCHY_DIR/bin/$cmd"
    else
      printf '#!/bin/bash\nexit 1\n' >"$MOCK_OMARCHY_DIR/bin/$cmd"
    fi
    chmod +x "$MOCK_OMARCHY_DIR/bin/$cmd"
  done
}

run_nvidia_env() {
  OMARCHY_PATH="$MOCK_OMARCHY_DIR" lua "$ROOT/test/shell.d/fixtures/hybrid-gpu-vaapi-intel.lua"
}

assert_env() {
  local description="$1" expected_libva="$2" expected_glx="$3"

  local output
  output=$(run_nvidia_env)

  local actual
  actual=$(echo "$output" | jq -r '.env.LIBVA_DRIVER_NAME // "unset"')
  [[ "$actual" == "$expected_libva" ]] || fail "$description" "LIBVA_DRIVER_NAME: expected $expected_libva, got: $actual"
  actual=$(echo "$output" | jq -r '.env.__GLX_VENDOR_LIBRARY_NAME // "unset"')
  [[ "$actual" == "$expected_glx" ]] || fail "$description" "__GLX_VENDOR_LIBRARY_NAME: expected $expected_glx, got: $actual"
  pass "$description"
}

# --- Case 1: non-hybrid desktop NVIDIA (GSP) ---------------------------
mock_hw_commands "no" "yes" "no"
assert_env "non-hybrid GSP desktop uses nvidia for both GL and VA-API" "nvidia" "nvidia"

# --- Case 2: hybrid laptop (GSP) --------------------------------------
mock_hw_commands "yes" "yes" "no"
assert_env "hybrid GSP laptop uses Intel iHD for VA-API, nvidia for GL" "iHD" "nvidia"

# --- Case 3: non-hybrid desktop NVIDIA (without GSP) ------------------
mock_hw_commands "no" "no" "yes"
assert_env "non-hybrid non-GSP desktop uses nvidia for both GL and VA-API" "nvidia" "nvidia"

# --- Case 4: hybrid laptop (without GSP) ------------------------------
mock_hw_commands "yes" "no" "yes"
assert_env "hybrid non-GSP laptop uses Intel iHD for VA-API, nvidia for GL" "iHD" "nvidia"

# --- Case 5: no NVIDIA GPU -------------------------------------------
mock_hw_commands "no" "no" "no"
assert_env "no NVIDIA GPU leaves both variables unset" "unset" "unset"

# --- Case 6: ordering — LIBVA_DRIVER_NAME after __GLX_VENDOR_LIBRARY_NAME
# in both branches, so a bare env dump that lists variables alphabetically or
# insertion-ordered cannot reorder them to mask a regression.
ordering() {
  local mock_hybrid="$1" mock_gsp="$2" mock_without_gsp="$3" branch="$4"

  mock_hw_commands "$mock_hybrid" "$mock_gsp" "$mock_without_gsp"
  local output
  output=$(run_nvidia_env)
  local glx_index
  glx_index=$(echo "$output" | jq -r '(.order | index("__GLX_VENDOR_LIBRARY_NAME")) // 0')
  local libva_index
  libva_index=$(echo "$output" | jq -r '(.order | index("LIBVA_DRIVER_NAME")) // 0')
  (( glx_index > 0 && libva_index > 0 )) || fail "both env vars are set in $branch branch"
  (( glx_index < libva_index )) || fail "__GLX_VENDOR_LIBRARY_NAME is set before LIBVA_DRIVER_NAME in $branch branch" "glx=$glx_index libva=$libva_index"
  pass "$branch branch sets __GLX_VENDOR_LIBRARY_NAME before LIBVA_DRIVER_NAME"
}

ordering "yes" "yes" "no" "hybrid GSP"
ordering "yes" "no" "yes" "hybrid non-GSP"
