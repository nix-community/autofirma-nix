{ pkgs, lib, ... }:
let
  stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
in
{
    test-support.displayManager.auto.user = "autofirma-user";

    users.users.autofirma-user = {
      isNormalUser = true;
    };

    home-manager.users.autofirma-user = {config, ... }: {
      xsession.enable = true;
      xsession.initExtra = ''
        xhost +SI:localuser:root
      '';

      home.stateVersion = stateVersion;
    };

    environment.systemPackages = with pkgs; [
      xorg.xhost.out
    ];

    system.stateVersion = stateVersion;
}
