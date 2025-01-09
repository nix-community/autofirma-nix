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
      default = cfg.package.overrideAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs or [] ++ [ pkgs.makeWrapper ];
        
        postFixup = old.postFixup + ''
          mv $out/bin/dnieremotewizard $out/bin/dnieremotewizard-customwrap
          cat > $out/bin/dnieremotewizard <<'EOF'
          #!${pkgs.stdenv.shell}
          export XAUTHORITY=$HOME/.Xauthority
          export HOME=/etc/dnieRemote
          EOF
          cat >> $out/bin/dnieremotewizard <<EOF
          exec $out/bin/dnieremotewizard-customwrap "\$@"
          EOF
          chmod +x $out/bin/dnieremotewizard
        '';
      });
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
      description = "Skip the intro and jump to a specific screen.";
    };
    wifiPort = mkOption {
      type = types.int;
      default = 9501;
      description = "The port to use for the Wi-Fi connection.";
    };
    usbPort = mkOption {
      type = types.int;
      default = 9501;
      description = "The port to use for the USB connection.";
    };
    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the firewall for the selected port.";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [cfg.finalPackage];
    environment.etc."dnieRemote/dnieRemote.cfg".text = ''
      jumpintro=${intro2value.${cfg.jumpIntro}};
      wifiport=${toString cfg.wifiPort};
      usbport=${toString cfg.usbPort};
    '';
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.wifiPort ];
    };
  };
}
