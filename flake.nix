{
  description = "A Nix flake for AutoFirma and related Spanish e-signature tools.";

  nixConfig = {
    extra-substituters = [
      "https://autofirma-nix.cachix.org"
    ];
    extra-trusted-public-keys = [
      "autofirma-nix.cachix.org-1:cDC9Dtee+HJ7QZcM8s36836scXyRToqNX/T+yvjiI0E="
    ];
  };

  # Common inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    flake-parts.url = "github:hercules-ci/flake-parts";
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
        packages.x86_64-linux = let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          ignoreVulnerable_openssl_1_1 = pkgs.openssl_1_1.overrideAttrs (oldAttrs: rec {
            meta = (oldAttrs.meta or {}) // {knownVulnerabilities = [];};
          });
        in {
          dnieremote = pkgs.callPackage ./nix/dnieremote/default.nix {openssl_1_1 = ignoreVulnerable_openssl_1_1;};
          configuradorfnmt = pkgs.callPackage ./nix/configuradorfnmt/default.nix {};
        };
      };
      systems = [
        "x86_64-linux"
        "i686-linux"
      ];
      perSystem = {
        config,
        system,
        self',
        ...
      }: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        formatter = pkgs.alejandra;
        packages = let
          prestadores = pkgs.callPackage ./nix/autofirma/truststore/prestadores {};
          pom-tools = pkgs.callPackage ./nix/tools/pom-tools {};
          jmulticard = pkgs.callPackage ./nix/autofirma/dependencies/jmulticard {
            inherit pom-tools;

            src = jmulticard-src;

            maven-dependencies-hash = "sha256-qI6gYbGKTQ4Q4tV8NI37TSd3eQTyHHgndUGS943UvNU=";
          };
          clienteafirma-external = pkgs.callPackage ./nix/autofirma/dependencies/clienteafirma-external {
            inherit pom-tools;

            src = clienteafirma-external-src;

            maven-dependencies-hash = "sha256-N2lFeRM/eu/tMFTCQRYSHYrbXNgbAv49S7qTaUmb2+Q=";
          };
        in rec {
          autofirma-truststore = pkgs.callPackage ./nix/autofirma/truststore {
            caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
            govTrustedCerts = prestadores;
          };
          download-autofirma-trusted-providers = pkgs.callPackage ./nix/tools/download-autofirma-trusted-providers {};
          download-url-linked-CAs = pkgs.callPackage ./nix/tools/download-url-linked-CAs {};
          autofirma = pkgs.callPackage ./nix/autofirma/default.nix {
            inherit jmulticard clienteafirma-external pom-tools autofirma-truststore;

            src = autofirma-src;

            maven-dependencies-hash = "sha256-zPWjBu1YtN0U9+wy/WG0NWg1EsO3MD0nhnkUsV7h6Ew=";
          };
          docs = import ./docs { inherit pkgs inputs; inherit (nixpkgs) lib; };
          default = self'.packages.autofirma;
        };
        checks = {
          nixos-autofirma-cli-sign-document = pkgs.callPackage ./nix/tests/nixos/autofirma/cli/sign-document.nix { inherit self; };
          nixos-autofirma-firefoxIntegration-sign-document = pkgs.callPackage ./nix/tests/nixos/autofirma/firefoxIntegration/sign-document.nix { inherit self; };
          nixos-configuradorfnmt-firefoxIntegration-request = pkgs.callPackage ./nix/tests/nixos/configuradorfnmt/firefoxIntegration/request-certificate.nix { inherit self; };
          hm-as-nixos-module-autofirma-cli-sign-document = pkgs.callPackage ./nix/tests/hm-as-nixos-module/autofirma/cli/sign-document.nix { inherit self home-manager; };
        };
      };
    };
}
