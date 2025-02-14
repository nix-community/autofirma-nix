inputs: {
  pkgs,
  osConfig,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.autofirma;
  ca-certificates = if osConfig != null then osConfig.environment.etc."ssl/certs/ca-certificates.crt".source else "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  inherit (pkgs.stdenv.hostPlatform) system;
  create-autofirma-cert = pkgs.writeShellApplication {
    name = "create-autofirma-cert";
    runtimeInputs = with pkgs; [ openssl ];
    text = builtins.readFile ./create-autofirma-cert;
  };
  anyFirefoxIntegrationProfileIsEnabled = builtins.any (x: x.enable) (lib.attrsets.attrValues cfg.firefoxIntegration.profiles);
in {
  options.programs.autofirma.truststore = {
    package = mkPackageOption inputs.self.packages.${system} "autofirma-truststore" {};
    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = cfg.truststore.package;
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

    firefoxIntegration.profiles = mkOption {
      type = types.attrsOf (types.submodule ({
        config,
        name,
        ...
      }: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
            description = "Profile name.";
          };

          enable = mkEnableOption "Enable Autofirma in this firefox profile.";
        };
      }));
      description = "Firefox profiles to integrate Autofirma with.";
    };
  };
  config = mkIf cfg.enable {
    home.activation.createAutoFirmaCert = lib.hm.dag.entryAfter ["writeBoundary"] ''
      verboseEcho Running create-autofirma-cert
      run ${lib.getExe create-autofirma-cert} $VERBOSE_ARG ${config.home.homeDirectory}/.afirma/Autofirma
    '';
    home.packages = [cfg.finalPackage];
    programs.firefox.policies.Certificates = mkIf anyFirefoxIntegrationProfileIsEnabled {
      ImportEnterpriseRoots = true;
      Install = [ "${config.home.homeDirectory}/.afirma/Autofirma/Autofirma_ROOT.cer" ];
    };
    programs.firefox.profiles = flip mapAttrs cfg.firefoxIntegration.profiles (name: {enable, ...}: {
      settings = mkIf enable {
        "network.protocol-handler.app.afirma" = "${cfg.finalPackage}/bin/autofirma";
        "network.protocol-handler.warn-external.afirma" = false;
        "network.protocol-handler.external.afirma" = true;
      };
    });
  };
}
