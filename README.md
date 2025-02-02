# Nix kernel development VM

This repository contains a [Nix] shell that makes it easy to build a Linux
kernel from source and test it in a virtual machine.

Any host Linux platform with Nix is supported.

[nix]: https://nixos.org

## Goals

_Why use this over other kernel development solutions?_

- **Easy build environment setup**: The shell provides all build dependencies, including the toolchain!
- **Rapid iteration**: With incremental compilation, it only takes 8 seconds on my machine to go from source to a guest shell prompt.
- **Minimal disk footprint**: The only substantial file generated is an initial ramdisk. The guest uses a tmpfs root, and all OS files are mounted directly from the host.
- **Rich guest environment**: A complete NixOS installation is available in the VM. No more tiny custom rootfses!
- **High configurability (QEMU + OS settings)**: QEMU and the guest OS can be configured to your liking.

## Usage

### Quick start

1. Clone the Linux kernel sources, enter the directory
2. ```console
   $ nix-shell path/to/this/repo
   ```
   > This may take some some; the guest NixOS system will be evaluated and built.
3. ```console
   $ genconfig
   ```
   > This only needs to be run once (or whenever the Nix kernel config is updated).
4. ```console
   $ launch
   ```
   > After some time, the guest will boot. Future invocations will be faster.
5. A guest console should open, logged in as `root`. You can use it normally, or
   use some [special QEMU commands](https://www.qemu.org/docs/master/system/mux-chardev.html).

After making kernel code changes, repeat from step 4 to test.

### Configuring QEMU and the guest OS

The guest OS is [NixOS][nix], which is configured in _modules_. When running
`nix-shell`, a module of your own can be included with the `configuration`
argument, and the `launch` command will use it.

```console
$ nix-shell path/to/this/repo --arg configuration path/to/configuration.nix

$ # Or, for small changes:
$ nix-shell path/to/this/repo --arg configuration '{ my.option = "abc"; }'
```

For example, here's a module I use to debug an ASUS USB keyboard driver. It
modifies some QEMU options, enables a kernel module, and installs a CLI utility.

`configuration.nix`

```nix
{
  virtualisation.vmVariant.virtualisation = {
    memorySize = 512;
    cores = 4;
    qemu.options = [
      "-device qemu-xhci"
      "-device usb-host,vendorid=0x0b05,productid=0x1b2c"
    ];
  };

  system.customKernelConfig = {
    HID_ASUS = true;
  };

  environment.systemPackages = with pkgs; [
    usbutils
  ];
}
```

#### Enabling graphics

For convenience, graphics are disabled, and the console is available through
your terminal.

If you desire a full QEMU window, however, you can enable it:

```nix
{
  virtualisation.vmVariant.virtualisation.graphics = true;
}
```

You may also wish to install a desktop environment and enable 3D acceleration.  
Here's an example with GNOME and VirGL - consult the NixOS and QEMU
documentation for more details. You may need [nixGL](https://github.com/nix-community/nixGL).

```nix
{
  virtualisation.vmVariant.virtualisation = {
    graphics = true;
    qemu.options = [ "-device virtio-vga-gl" "-display gtk,gl=on" ];
  };

  system.customKernelConfig = {
    DRM = true;
    DRM_VIRTIO_GPU_KMS = true;
    DRM_FBDEV_EMULATION = true;
    FRAMEBUFFER_CONSOLE = true;
  };

  hardware.graphics.enable = true;

  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  users.users.root.password = "root";
}
```

### A note on kernel modules

In order to keep the kernel small, the regular list of kernel modules enabled by
NixOS is not used. Instead, the `system.customKernelConfig` option can be used
to enable or disable kernel configuration items.

Additionally, kernel modules are not actually compiled as modules, but are
rather built in to the kernel directly. This is because the NixOS VM system does
not provide an easy way to load external modules with a custom kernel.

These changes in behavior may break some NixOS features. If this occurs, the
kernel modules they need must be enabled manually.
