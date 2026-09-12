if omarchy-hw-msi; then
  omarchy-pkg-add msi-perkeyrgb

  # Check if this MSI laptop has a Killer E-series Ethernet (RTL8125B)
  if lspci | grep -qiE "Killer.*2\.5.*GbE|RTL8125"; then
    omarchy-pkg-add r8125-dkms

    # Blacklist r8169 so r8125 loads exclusively. Without this, both
    # modules can bind to the Killer E3000, causing flapping and
    # panic on link renegotiation under sustained 2.5GbE load.
    mkdir -p /etc/modprobe.d
    echo "blacklist r8169" > /etc/modprobe.d/r8169.conf

    # Ensure r8125 loads at boot
    mkdir -p /etc/modules-load.d
    echo "r8125" > /etc/modules-load.d/r8125.conf

    sudo mkinitcpio -P
  fi

  # MSI Embedded Controller — required for fan modes, shift modes,
  # battery thresholds, and other laptop-specific features.
  if ! lsmod | grep -q msi_ec; then
    omarchy-pkg-add msi-ec-dkms-git
  fi

  # CoolerControl for fan curves + thermal management. Conflicts with
  # thermald (generic DPTF) on MSI laptops — coolercontrold talks to
  # the EC directly and knows the MSI fan table.
  omarchy-pkg-add coolercontrol
  sudo systemctl disable --now thermald.service 2>/dev/null || true
  sudo systemctl enable --now coolercontrold.service

  # NVIDIA-settings for GPU monitoring and tuning on MSI dGPU laptops
  if omarchy-hw-nvidia; then
    omarchy-pkg-add nvidia-settings

    # X11 config for DPMS and backlight control via nvidia-settings
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/10-nvidia-dpms.conf <<'EOF'
Section "Device"
    Identifier "NVIDIA Card"
    Driver "nvidia"
    Option "RegistryDwords" "EnableBrightnessControl=1"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "NVIDIA Card"
    Option "AllowNVIDIAGPUScreens" "on"
EndSection
EOF
  fi

  # Rebuild initcpio with EC module if msi-ec is loaded
  if lsmod | grep -q msi_ec; then
    mkdir -p /etc/mkinitcpio.conf.d
    cat > /etc/mkinitcpio.conf.d/msi.conf <<'EOF'
MODULES+=(msi_ec)
EOF
    sudo mkinitcpio -P
  fi
fi
