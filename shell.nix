{ pkgs ? import <nixpkgs> {} }:

with pkgs;
mkShell {

  packages = [
    bc
    flex
    bison
    elfutils
    openssl
    zlib
    glibc.static
    gcc
    gdb

  (writeShellApplication {
      name = "create_disk";
      runtimeInputs = [
        pkgs.debootstrap
      ];
      text = ''
      dd if=/dev/zero of=./rootfs.img bs=1G count=2 status=progress
      mkfs.ext4 ./rootfs.img
      sudo mount ./rootfs.img /mnt
      sudo chown -R "$USER:" /mnt

      sudo debootstrap --arch amd64 stable /mnt
      chroot /mnt /bin/bash<<eof
      echo -e "pass\npass" | passwd root
      eof
      
      sudo umount /mnt
      '';
  })

  (writeShellApplication {
      name = "start_vm";
      runtimeInputs = [
        pkgs.qemu
      ];
      text = ''
      qemu-system-x86_64 \
          -kernel ./arch/x86_64/boot/bzImage \
          -append "console=ttyS0,115200 root=/dev/vda rw init=/bin/bash" \
          -drive file=./rootfs.img,format=raw,if=virtio \
          -m 2G \
          -nographic \
          -enable-kvm
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

}
