{ pkgs ? import <nixpkgs> {} }:

with pkgs;
mkShell {

  packages = [
    bc
    flex
    bison
    elfutils
    openssl
  ];

  shellHook = ''
    # Reproducability (helps speed up rebuilds)
    export KBUILD_BUILD_TIMESTAMP="$(date -u -d @$SOURCE_DATE_EPOCH)"
    export KBUILD_BUILD_VERSION=1-NixOS
    export KBUILD_BUILD_USER=user
    export KBUILD_BUILD_HOST=machine
  '';

}
