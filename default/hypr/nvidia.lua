local paths = require("default.hypr.paths")

local nvidia = paths.omarchy_path .. "/bin/omarchy-hw-nvidia"
local nvidia_gsp = paths.omarchy_path .. "/bin/omarchy-hw-nvidia-gsp"
local nvidia_without_gsp = paths.omarchy_path .. "/bin/omarchy-hw-nvidia-without-gsp"
local hybrid_gpu = paths.omarchy_path .. "/bin/omarchy-hw-hybrid-gpu"

-- These detectors read cached sysfs IDs rather than shelling out to lspci.
-- lspci reads PCI config space, which resumes a runtime-suspended GPU, and on a
-- hybrid laptop that wake alone outlasts Hyprland's 1.5s config reload budget.
if o.shell_succeeds(o.shell_quote(nvidia)) then
  if o.shell_succeeds(o.shell_quote(nvidia_gsp)) then
    hl.env("NVD_BACKEND", "direct")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    -- On hybrid laptops, the panel scans out through the Intel iGPU. Using
    -- the nvidia VA-API driver for video decode produces broken playback in
    -- Chromium-based browsers (black screen, spinner, audio-only) because the
    -- decoded frames cannot be handed back to the Intel compositor over
    -- Wayland. Point VA-API at the Intel iHD driver so the iGPU's hardware
    -- decoder handles VP9/AV1, which scans out locally. The nvidia GPU
    -- remains available for GL rendering and CUDA.
    if o.shell_succeeds(o.shell_quote(hybrid_gpu)) then
      hl.env("LIBVA_DRIVER_NAME", "iHD")
    else
      hl.env("LIBVA_DRIVER_NAME", "nvidia")
    end
  elseif o.shell_succeeds(o.shell_quote(nvidia_without_gsp)) then
    hl.env("NVD_BACKEND", "egl")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    if o.shell_succeeds(o.shell_quote(hybrid_gpu)) then
      hl.env("LIBVA_DRIVER_NAME", "iHD")
    else
      hl.env("LIBVA_DRIVER_NAME", "nvidia")
    end
  end
end
