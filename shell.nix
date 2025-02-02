{ configuration ? { } }:

let
  vmSystem = import <nixpkgs/nixos> {
    configuration = { modulesPath, config, lib, ... }: {
      imports = [
        (modulesPath + "/profiles/minimal.nix")
        configuration
      ];

      options = {
        system.customKernelConfig = lib.mkOption {
          type = with lib.types; attrsOf bool;
          description = "Kernel configuration values to set in the genConfig script.";
          default = { };
        };
      };

      config = {
        system.name = "kernelvm";

        virtualisation.vmVariant.virtualisation = {
          diskImage = null;
          graphics = lib.mkDefault false;
        };

        boot = {
          kernelParams = [ "earlyprintk=serial" ];
          consoleLogLevel = lib.mkDefault 8;
        };

        networking.firewall.enable = lib.mkDefault false; # Requires extra kernel modules.

        services.getty.autologinUser = config.users.users.root.name;

        system.customKernelConfig = {
          # Required QEMU/NixOS features
          MODULES = false;
          PVH = true;
          OVERLAY_FS = true;

          # Large unnecessary features
          DRM_I915 = lib.mkDefault false;
        };

        system.build.genConfigScript = ''
          make defconfig kvm_guest.config

          ./scripts/config \
            ${lib.concatMapAttrsStringSep " \\\n" (name: value: "${if value then "--enable" else "--disable"} ${name}") config.system.customKernelConfig}

          make olddefconfig
        '';
      };
    };
  };
in

with vmSystem.pkgs;

mkShell {
  inputsFrom = [ vmSystem.config.boot.kernelPackages.kernel ];

  packages = [
    pkg-config
    ncurses
    qt6.qtbase
    qt6.qtwayland

    (writeShellApplication {
      name = "genconfig";
      text = vmSystem.config.system.build.genConfigScript;
    })

    (writeShellApplication {
      name = "launch";
      text = ''
        make -j"$(nproc)" vmlinux
        NIXPKGS_QEMU_KERNEL_${vmSystem.config.system.name}="$PWD/vmlinux" '${lib.getExe vmSystem.vm}'
      '';
    })
  ];

  shellHook = ''
    # Reproducability (helps speed up rebuilds)
    export KBUILD_BUILD_TIMESTAMP="$(date -u -d @$SOURCE_DATE_EPOCH)"
    export KBUILD_BUILD_VERSION=1-NixOS
    export KBUILD_BUILD_USER=user
    export KBUILD_BUILD_HOST=machine
  '';

  passthru = { inherit vmSystem; };
}
