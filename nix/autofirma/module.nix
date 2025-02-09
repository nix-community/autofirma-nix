inputs: {
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.autofirma;
  inherit (pkgs.stdenv.hostPlatform) system;
  create-autofirma-cert = pkgs.writeShellApplication {
    name = "create-autofirma-cert";
    runtimeInputs = with pkgs; [ openssl ];
    text = builtins.readFile ./create-autofirma-cert;
  };
in {
  options.programs.autofirma.truststore = {
    package = mkPackageOption inputs.self.packages.${system} "autofirma-truststore" {};
    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = cfg.truststore.package.override { caBundle = config.environment.etc."ssl/certs/ca-certificates.crt".source; };
      defaultText =
        literalExpression
        "`programs.autofirma.truststore.package` with applied configuration";
      description = ''
        The Autofirma truststore package after applying configuration.
      '';
    };
  };

  options.programs.autofirma = {
    enable = mkEnableOption "Autofirma";
    fixJavaCerts = mkEnableOption "Fix Java certificates";
    package = mkPackageOption inputs.self.packages.${system} "autofirma" {};
    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = cfg.package.override {
        autofirma-truststore = cfg.truststore.finalPackage;
        firefox = config.programs.firefox.package;
      };
      defaultText =
        literalExpression
        "`programs.autofirma.package` with applied configuration";
      description = ''
        The Autofirma package after applying configuration.
      '';
    };
    firefoxIntegration.enable = mkEnableOption "Firefox integration";
  };

  config.environment.systemPackages = mkIf cfg.enable (lib.warnIf cfg.fixJavaCerts "The option `programs.autofirma.fixJavaCerts` is deprecated." [
    cfg.finalPackage
  ]);

  config.programs = mkIf cfg.enable {
    firefox = mkIf cfg.firefoxIntegration.enable {
      autoConfigFiles = lib.mkAfter [
        "${cfg.finalPackage}/etc/firefox/pref/AutoFirma.js"
      ];
      policies.Certificates.ImportEnterpriseRoots = true;
      policies.Certificates.Install = [ "/etc/Autofirma/AutoFirma_ROOT.cer" ];
    };
  };

  config.systemd.services = mkIf (cfg.enable && cfg.firefoxIntegration.enable) {
    create-autofirma-cert = {
      enable = true;
      description = "Create certificate for Autofirma and browser communication";
      wants = [ "display-manager.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe create-autofirma-cert} /etc/Autofirma";
        RemainAfterExit = true;
      };
      wantedBy = [ "multi-user.target" ];
    };
  };

}
