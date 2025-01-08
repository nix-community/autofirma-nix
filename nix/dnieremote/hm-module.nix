inputs: {
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.dnieremote;
  intro2value = {
    "no" = "0";
    "usb" = "241";
    "wifi" = "242";
  };
  inherit (pkgs.stdenv.hostPlatform) system;
in {
  options.programs.dnieremote = {
    enable = mkEnableOption "DNIeRemote";
    package = mkPackageOption inputs.self.packages.${system} "dnieremote" {};
    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = cfg.package;
      defaultText =
        literalExpression
        "`programs.dnieremote.package` with applied configuration";
      description = ''
        The DNIeRemote package after applying configuration.
      '';
    };
    jumpIntro = mkOption {
      type = types.enum [ "usb" "wifi" "no" ];
      default = "no";
      description = "Jump to the intro screen after the DNIeRemote is started.";
    };
    wifiPort = mkOption {
      type = types.int;
      default = 9501;
      description = "The port to use for the wifi connection.";
    };
    usbPort = mkOption {
      type = types.int;
      default = 9501;
      description = "The port to use for the usb connection.";
    };
  };
  config = mkIf cfg.enable {
    home.packages = [cfg.finalPackage];
    home.file."dnieRemote.cfg".text = ''
      jumpintro=${intro2value.${cfg.jumpIntro}};
      wifiport=${toString cfg.wifiPort};
      usbport=${toString cfg.usbPort};
    '';
  };
}
