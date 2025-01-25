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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
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
        devShells.default = let
          update-fixed-output-derivations = pkgs.callPackage ./nix/tools/update-fixed-output-derivations {};
        in 
        pkgs.mkShell {
          packages = [
            update-fixed-output-derivations
          ];
        };
        packages = rec {
          fixed-output-derivations = builtins.fromJSON (builtins.readFile ./fixed-output-derivations.lock);
          pom-tools = pkgs.callPackage ./nix/pom-tools {};
          jmulticard = pkgs.callPackage ./nix/autofirma/dependencies/jmulticard {
            inherit pom-tools;

            src = jmulticard-src;

            maven-dependencies-hash = fixed-output-derivations."jmulticard".hash;
          };
          clienteafirma-external = pkgs.callPackage ./nix/autofirma/dependencies/clienteafirma-external {
            inherit pom-tools;

            src = clienteafirma-external-src;

            maven-dependencies-hash = fixed-output-derivations."clienteafirma-external".hash;
          };
          autofirma = pkgs.callPackage ./nix/autofirma/default.nix {
            inherit jmulticard clienteafirma-external pom-tools;

            src = autofirma-src;

            maven-dependencies-hash = fixed-output-derivations."autofirma".hash;
          };
          default = self'.packages.autofirma;
        };
        checks = {
          # autofirma-sign = pkgs.runCommand "autofirma-sign" {} ''
          #   mkdir -p $out
          #   echo "NixOS AutoFirma Sign Test" > document.txt
          #
          #   ${inputs.nixpkgs.lib.getExe pkgs.openssl} req -x509 -newkey rsa:2048 -keyout private.key -out certificate.crt -days 365 -nodes -subj "/C=ES/O=TEST AUTOFIRMA NIX/OU=DNIE/CN=AC DNIE 004" -passout pass:1234
          #   ${inputs.nixpkgs.lib.getExe pkgs.openssl} pkcs12 -export -out certificate.p12 -inkey private.key -in certificate.crt -name "testcert" -password pass:1234
          #
          #   ${inputs.nixpkgs.lib.getExe self'.packages.autofirma} sign -store pkcs12:certificate.p12 -i document.txt -o document.txt.sign -filter alias.contains=testcert -password 1234 -xml
          # '';
        };
      };
    };
}
