{
  description = "A Nix flake for AutoFirma and related Spanish e-signature tools.";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # Common inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    nix-unit.inputs.flake-parts.follows = "flake-parts";
  };

  # Autofirma sources
  inputs = {
    jmulticard-src = {
      url = "github:ctt-gob-es/jmulticard/v1.8";
      flake = false;
    };

    clienteafirma-external-src = {
      url = "github:ctt-gob-es/clienteafirma-external/OT_14395";
      flake = false;
    };

    autofirma-src = {
      url = "github:ctt-gob-es/clienteafirma/v1.8.3";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    home-manager,
    jmulticard-src,
    clienteafirma-external-src,
    autofirma-src,
    nix-unit
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      flake = {
        homeManagerModules = rec {
          autofirma = import ./nix/autofirma/hm-module.nix inputs;
          dnieremote = import ./nix/dnieremote/hm-module.nix inputs;
          configuradorfnmt = import ./nix/configuradorfnmt/hm-module.nix inputs;
          default = {
            imports = [
              autofirma
              dnieremote
              configuradorfnmt
            ];
          };
        };
        nixosModules = rec {
          autofirma = import ./nix/autofirma/module.nix inputs;
          dnieremote = import ./nix/dnieremote/module.nix inputs;
          configuradorfnmt = import ./nix/configuradorfnmt/module.nix inputs;
          default = {
            imports = [
              autofirma
              dnieremote
              configuradorfnmt
            ];
          };
        };
        templates = {
          nixos-module = {
            path = ./templates/nixos-module;
            description = "NixOS system with AutoFirma (system-wide installation)";
          };
          home-manager-nixos = {
            path = ./templates/home-manager-nixos;
            description = "Home Manager with NixOS for AutoFirma (user-specific installation)";
          };
          home-manager-standalone = {
            path = ./templates/home-manager-standalone;
            description = "Home Manager Standalone for AutoFirma (user-specific installation without NixOS)";
          };
          default = self.templates.nixos-module;
        };
        packages.x86_64-linux = let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          ignoreVulnerable_openssl_1_1 = pkgs.openssl_1_1.overrideAttrs (oldAttrs: rec {
            meta = (oldAttrs.meta or {}) // {knownVulnerabilities = [];};
          });
        in {
          dnieremote = pkgs.callPackage ./nix/dnieremote/default.nix {openssl_1_1 = ignoreVulnerable_openssl_1_1;};
          configuradorfnmt = pkgs.callPackage ./nix/configuradorfnmt/default.nix {};
        };
        tests = import ./nix/tests/unit { inherit self; }; 
        checks.x86_64-linux = let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in {
          # NiXOS Modules
          ## Configurador FNMT-RCM
          nixos-configuradorfnmt-firefoxIntegration-request = pkgs.callPackage ./nix/tests/nixos/configuradorfnmt/firefoxIntegration/request-certificate.nix { inherit self; };
          ##DNIe Remote
          nixos-dnieremote-config-jumpintro-wifi = pkgs.callPackage ./nix/tests/nixos/dnieremote/config/jumpintro-wifi.nix { inherit self; };
          nixos-dnieremote-config-jumpintro-usb = pkgs.callPackage ./nix/tests/nixos/dnieremote/config/jumpintro-usb.nix { inherit self; };
          nixos-dnieremote-config-jumpintro-no = pkgs.callPackage ./nix/tests/nixos/dnieremote/config/jumpintro-no.nix { inherit self; };
          nixos-dnieremote-config-wifiport = pkgs.callPackage ./nix/tests/nixos/dnieremote/config/wifiport.nix { inherit self; };
          # Home Manager Modules
          ## HM installed as a NixOS Module
          ### Configurador FNMT-RCM
          hm-as-nixos-module-configuradorfnmt-firefoxIntegration-request = pkgs.callPackage ./nix/tests/hm-as-nixos-module/configuradorfnmt/firefoxIntegration/request-certificate.nix { inherit self home-manager; };
          ### DNIe Remote
          hm-as-nixos-module-dnieremote-config-jumpintro-wifi = pkgs.callPackage ./nix/tests/hm-as-nixos-module/dnieremote/config/jumpintro-wifi.nix { inherit self home-manager; };
          hm-as-nixos-module-dnieremote-config-jumpintro-usb = pkgs.callPackage ./nix/tests/hm-as-nixos-module/dnieremote/config/jumpintro-usb.nix { inherit self home-manager; };
          hm-as-nixos-module-dnieremote-config-jumpintro-no = pkgs.callPackage ./nix/tests/hm-as-nixos-module/dnieremote/config/jumpintro-no.nix { inherit self home-manager; };
          hm-as-nixos-module-dnieremote-config-wifiport = pkgs.callPackage ./nix/tests/hm-as-nixos-module/dnieremote/config/wifiport.nix { inherit self home-manager; };
          ## HM standalone installation
          ### Configurador FNMT-RCM
          hm-standalone-configuradorfnmt-firefoxIntegration-request = pkgs.callPackage ./nix/tests/hm-standalone/configuradorfnmt/firefoxIntegration/request-certificate.nix { inherit self home-manager; };
          ### DNIe Remote
          hm-standalone-dnieremote-config-jumpintro-wifi = pkgs.callPackage ./nix/tests/hm-standalone/dnieremote/config/jumpintro-wifi.nix { inherit self home-manager; };
          hm-standalone-dnieremote-config-jumpintro-usb = pkgs.callPackage ./nix/tests/hm-standalone/dnieremote/config/jumpintro-usb.nix { inherit self home-manager; };
          hm-standalone-dnieremote-config-jumpintro-no = pkgs.callPackage ./nix/tests/hm-standalone/dnieremote/config/jumpintro-no.nix { inherit self home-manager; };
          hm-standalone-dnieremote-config-wifiport = pkgs.callPackage ./nix/tests/hm-standalone/dnieremote/config/wifiport.nix { inherit self home-manager; };
        };
      };
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.nix-unit.modules.flake.default
      ];
      perSystem = {
        config,
        system,
        self',
        lib,
        ...
      }: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        nix-unit.inputs = {
          inherit (inputs) nixpkgs flake-parts nix-unit;
        };
        formatter = pkgs.alejandra;
        overlayAttrs = {
          inherit (config.packages) autofirma; # configuradorfnmt dnieremote are specific to x86_64-linux
        };
        devShells.default = let
          update-fixed-output-derivations = pkgs.callPackage ./nix/tools/update-fixed-output-derivations {};
          download-autofirma-trusted-providers = pkgs.callPackage ./nix/tools/download-autofirma-trusted-providers {};
          download-url-linked-CAs = pkgs.callPackage ./nix/tools/download-url-linked-CAs {};
        in 
        pkgs.mkShell {
          packages = [
            pkgs.jq
            update-fixed-output-derivations
            download-autofirma-trusted-providers
            download-url-linked-CAs
            nix-unit.packages.${system}.default
          ];
        };
        packages = let
          fixed-output-derivations = builtins.fromJSON (builtins.readFile ./fixed-output-derivations.lock);
          prestadores = pkgs.callPackage ./nix/autofirma/truststore/prestadores {};
          pom-tools = pkgs.callPackage ./nix/tools/pom-tools {};
          properties-to-json = pkgs.callPackage ./nix/tools/properties-to-json {};
          jmulticard = pkgs.callPackage ./nix/autofirma/dependencies/jmulticard {
            inherit pom-tools;

            src = jmulticard-src;

            maven-dependencies-hash = fixed-output-derivations."autofirma.clienteafirma.dependencies.jmulticard".hash;
          };
          clienteafirma-external = pkgs.callPackage ./nix/autofirma/dependencies/clienteafirma-external {
            inherit pom-tools;

            src = clienteafirma-external-src;

            maven-dependencies-hash = fixed-output-derivations."autofirma.clienteafirma.dependencies.clienteafirma-external".hash;
          };
        in rec {
          autofirma-truststore = pkgs.callPackage ./nix/autofirma/truststore {
            govTrustedCerts = prestadores;
          };
          autofirma = pkgs.callPackage ./nix/autofirma/default.nix {
            inherit jmulticard clienteafirma-external pom-tools autofirma-truststore properties-to-json;

            src = autofirma-src;

            maven-dependencies-hash = fixed-output-derivations."autofirma.clienteafirma".hash;
          };
          docs = import ./docs { inherit pkgs inputs; inherit (nixpkgs) lib; };
          default = self'.packages.autofirma;
        };
        checks = let
          blacklistPackages = [ "docs" ];
          packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") (lib.filterAttrs (n: _v: !(builtins.elem n blacklistPackages)) self'.packages);
          checks = {
            # NixOS Modules
            ## AutoFirma
            nixos-autofirma-cli-sign-document = pkgs.callPackage ./nix/tests/nixos/autofirma/cli/sign-document.nix { inherit self; };
            nixos-autofirma-firefoxIntegration-protocol-handler = pkgs.callPackage ./nix/tests/nixos/autofirma/firefoxIntegration/protocol-handler { inherit self; };
            nixos-autofirma-firefoxIntegration-connection-method-websocket = pkgs.callPackage ./nix/tests/nixos/autofirma/firefoxIntegration/connection-method/websocket { inherit self; };
            nixos-autofirma-firefoxIntegration-connection-method-xhr = pkgs.callPackage ./nix/tests/nixos/autofirma/firefoxIntegration/connection-method/xhr { inherit self; };
            nixos-autofirma-firefoxIntegration-connection-method-auxiliary-servers = pkgs.callPackage ./nix/tests/nixos/autofirma/firefoxIntegration/connection-method/auxiliary-servers { inherit self; };
            # Home Manager Modules
            ## HM installed as a NixOS Module
            ### AutoFirma
            hm-as-nixos-module-autofirma-cli-sign-document = pkgs.callPackage ./nix/tests/hm-as-nixos-module/autofirma/cli/sign-document.nix { inherit self home-manager; };
            hm-as-nixos-module-autofirma-firefoxIntegration-protocol-handler = pkgs.callPackage ./nix/tests/hm-as-nixos-module/autofirma/firefoxIntegration/protocol-handler { inherit self home-manager; };
            hm-as-nixos-module-autofirma-firefoxIntegration-connection-method-websocket = pkgs.callPackage ./nix/tests/hm-as-nixos-module/autofirma/firefoxIntegration/connection-method/websocket { inherit self home-manager; };
            hm-as-nixos-module-autofirma-firefoxIntegration-connection-method-xhr = pkgs.callPackage ./nix/tests/hm-as-nixos-module/autofirma/firefoxIntegration/connection-method/xhr { inherit self home-manager; };
            hm-as-nixos-module-autofirma-firefoxIntegration-connection-method-auxiliary-servers = pkgs.callPackage ./nix/tests/hm-as-nixos-module/autofirma/firefoxIntegration/connection-method/auxiliary-servers { inherit self home-manager; };
            hm-as-nixos-module-autofirma-config-omitAskOnClose = pkgs.callPackage ./nix/tests/hm-as-nixos-module/autofirma/config/omitAskOnClose.nix { inherit self home-manager; };
            # HM standalone installation
            ### AutoFirma
            hm-standalone-autofirma-cli-sign-document = pkgs.callPackage ./nix/tests/hm-standalone/autofirma/cli/sign-document.nix { inherit self home-manager; };
            hm-standalone-autofirma-firefoxIntegration-protocol-handler = pkgs.callPackage ./nix/tests/hm-standalone/autofirma/firefoxIntegration/protocol-handler { inherit self home-manager; };
            hm-standalone-autofirma-firefoxIntegration-connection-method-websocket = pkgs.callPackage ./nix/tests/hm-standalone/autofirma/firefoxIntegration/connection-method/websocket { inherit self home-manager; };
            hm-standalone-autofirma-firefoxIntegration-connection-method-xhr = pkgs.callPackage ./nix/tests/hm-standalone/autofirma/firefoxIntegration/connection-method/xhr { inherit self home-manager; };
            hm-standalone-autofirma-firefoxIntegration-connection-method-auxiliary-servers = pkgs.callPackage ./nix/tests/hm-standalone/autofirma/firefoxIntegration/connection-method/auxiliary-servers { inherit self home-manager; };
            hm-standalone-autofirma-config-omitAskOnClose = pkgs.callPackage ./nix/tests/hm-standalone/autofirma/config/omitAskOnClose.nix { inherit self home-manager; };
            # Overlay
            overlay = pkgs.callPackage ./nix/tests/overlay { inherit self; };
        };
      in
        checks // packages;
      };
    };
}
