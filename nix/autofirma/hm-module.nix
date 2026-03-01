inputs: {
  pkgs,
  osConfig,
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
  anyFirefoxIntegrationProfileIsEnabled = builtins.any (x: x.enable) (lib.attrsets.attrValues cfg.firefoxIntegration.profiles);
  defaultAutofirmaSettings = lib.recursiveUpdate cfg.finalPackage.clienteafirma.preferences {
    "default.locale".default = if osConfig ? defaultLocale then osConfig.defaultLocale else "en_US";
  };
  json-to-xmlprefs = name: value: pkgs.callPackage ({ runCommand, jq }: runCommand name {
      nativeBuildInputs = [ jq ];
      value = builtins.toJSON value;
      passAsFile = [ "value" ];
      preferLocalBuild = true;
    } ''
      (
        echo '<?xml version="1.0" encoding="UTF-8" standalone="no"?>'
        echo '<!DOCTYPE map SYSTEM "http://java.sun.com/dtd/preferences.dtd">'
        echo '<map MAP_XML_VERSION="1.0">'

        # Use jq to parse the JSON and emit each key/value pair as an XML entry
        jq -r '
            to_entries
            | .[]
            | "  <entry key=\"" + .key + "\" value=\"" + .value + "\"/>"
          ' "$valuePath"

        echo '</map>'
      ) > "$out"
    '') {}; 
  boolsToStrings = lib.attrsets.mapAttrs (_: v: if builtins.isBool v then lib.boolToString v else v);
  autofirma-prefs-format = {
    type = types.submodule {
      options = lib.attrsets.mapAttrs (_: value: mkOption rec {
        type = if value.default == "true" || value.default == "false" then types.bool else types.str;
        default = if (type == types.bool) then (value.default == "true") else value.default;
        description = if value ? description then value.description else "No description available";
      }) defaultAutofirmaSettings;
    };
    generate = name: value: json-to-xmlprefs name (boolsToStrings value);
  };
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

    config = mkOption {
      type = autofirma-prefs-format.type;
      description = "Settings to apply to the Autofirma package.";
      default = { };
    };

  };
  config = mkIf cfg.enable {
    home.activation = mkMerge [
      (mkIf true {
        createAutoFirmaCert = lib.hm.dag.entryAfter ["writeBoundary"] ''
          verboseEcho Running create-autofirma-cert
          run ${lib.getExe create-autofirma-cert} $VERBOSE_ARG ${config.home.homeDirectory}/.afirma/Autofirma
        '';
      })
      (mkIf ((boolsToStrings cfg.config) != defaultAutofirmaSettings) {
        unprotectAutoFirmaConfig = lib.hm.dag.entryBetween ["linkGeneration"] ["writeBoundary"] ''
          run mkdir -p "${config.home.homeDirectory}/.java/.userPrefs/es/gob/afirma/standalone/ui/preferences"
          run chmod --silent u+w "${config.home.homeDirectory}/.java/.userPrefs/es/gob/afirma/standalone/ui/preferences"
        '';
        protectAutoFirmaConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
          run chmod --silent u-w "${config.home.homeDirectory}/.java/.userPrefs/es/gob/afirma/standalone/ui/preferences"
        '';
      })
    ];
    home.packages = [cfg.finalPackage];

    home.file.".java/.userPrefs/es/gob/afirma/standalone/ui/preferences/prefs.xml" = mkIf ((boolsToStrings cfg.config) != defaultAutofirmaSettings) {
      source = autofirma-prefs-format.generate "prefs.xml" cfg.config;
    };

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
