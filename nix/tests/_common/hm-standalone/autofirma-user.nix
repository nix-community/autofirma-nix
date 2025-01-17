{ pkgs, lib, ... }:
let
  stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
in
{
    test-support.displayManager.auto.user = "autofirma-user";

    users.users.autofirma-user = {
      isNormalUser = true;
    };

    nix.settings = {
      extra-experimental-features = [ "nix-command" "flakes" ];
    };

    environment.systemPackages = with pkgs; [
      xorg.xhost.out
    ];

    system.stateVersion = stateVersion;
}

