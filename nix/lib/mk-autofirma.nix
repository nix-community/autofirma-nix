# Factory for the AutoFirma package set.
#
# AutoFirma is built from three Maven fixed-output derivations (FODs): the
# jmulticard and clienteafirma-external dependency repositories, and the
# clienteafirma dependency repository.  Their output hashes depend on the Maven
# that resolved them, because Maven downloads its own default lifecycle plugins
# into the repository.  The hashes committed in fixed-output-derivations.lock
# were computed with the Maven pinned by this flake's nixpkgs input.
#
# Downstream flakes usually follow their own nixpkgs
# (`autofirma-nix.inputs.nixpkgs.follows = "nixpkgs"`), which may ship a different
# Maven.  In that case the committed hashes no longer match.  mkAutofirma lets
# such users supply their own FOD hashes without forking:
#
#     autofirma = autofirma-nix.lib.mkAutofirma pkgs {
#       maven-dependencies-hash = {
#         "autofirma.clienteafirma.dependencies.jmulticard" = "sha256-…";
#         "autofirma.clienteafirma.dependencies.clienteafirma-external" = "sha256-…";
#         "autofirma.clienteafirma" = "sha256-…";
#       };
#     };
#
# The hashes are obtained by running `update-fixed-output-derivations` against
# the user's nixpkgs.  Only the hashes need overriding: the dependency version
# pins (maven-dependency-versions.lock) are forced through <dependencyManagement>
# and are therefore independent of the Maven version, so they are reused as-is.
{
  # The flake inputs providing the AutoFirma sources.
  jmulticard-src,
  clienteafirma-external-src,
  autofirma-src,
}: let
  # Default locks, read relative to this file so the factory works regardless of
  # the caller's working directory.
  default-fixed-output-derivations = builtins.fromJSON (builtins.readFile ../../fixed-output-derivations.lock);
  default-maven-dependency-versions = builtins.fromJSON (builtins.readFile ../../maven-dependency-versions.lock);
in
  # mkAutofirma :: pkgs -> overrides -> { autofirma, autofirma-truststore, … }
  #
  # `pkgs` is the caller's package set; its `maven` is the one used to build.
  # `overrides` may set:
  #   maven-dependencies-hash    attrset of FOD name -> sha256, defaulting to the
  #                              committed fixed-output-derivations.lock
  #   maven-dependency-versions  the version-pin lock, defaulting to the committed
  #                              maven-dependency-versions.lock (rarely overridden)
  pkgs: {
    maven-dependencies-hash ? default-fixed-output-derivations,
    maven-dependency-versions ? default-maven-dependency-versions,
  }: let
    hashFor = name: maven-dependencies-hash.${name}.hash;

    prestadores = pkgs.callPackage ../autofirma/truststore/prestadores {};
    pom-tools = pkgs.callPackage ../tools/pom-tools {};
    properties-to-json = pkgs.callPackage ../tools/properties-to-json {};

    jmulticard = pkgs.callPackage ../autofirma/dependencies/jmulticard {
      inherit pom-tools;
      src = jmulticard-src;
      maven-dependencies-hash = hashFor "autofirma.clienteafirma.dependencies.jmulticard";
      inherit maven-dependency-versions;
    };

    clienteafirma-external = pkgs.callPackage ../autofirma/dependencies/clienteafirma-external {
      inherit pom-tools;
      src = clienteafirma-external-src;
      maven-dependencies-hash = hashFor "autofirma.clienteafirma.dependencies.clienteafirma-external";
      inherit maven-dependency-versions;
    };

    autofirma-truststore = pkgs.callPackage ../autofirma/truststore {
      govTrustedCerts = prestadores;
    };

    autofirma = pkgs.callPackage ../autofirma/default.nix {
      inherit jmulticard clienteafirma-external pom-tools autofirma-truststore properties-to-json;
      src = autofirma-src;
      maven-dependencies-hash = hashFor "autofirma.clienteafirma";
      inherit maven-dependency-versions;
    };
  in {
    inherit autofirma autofirma-truststore jmulticard clienteafirma-external pom-tools properties-to-json;
  }
