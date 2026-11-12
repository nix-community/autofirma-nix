{
  lib,
  stdenv,
  fetchFromGitHub,
  maven,
  pom-tools,
  rsync,
  src,
  maven-dependencies-hash ? "",
  maven-dependency-versions ? {},
}: let
  name = "clienteafirma-external";

  clienteafirma-external-src = stdenv.mkDerivation {
    name = "${name}-src";

    inherit src;

    nativeBuildInputs = [pom-tools];

    dontBuild = true;

    patchPhase = ''
      find . -name '*.jar' -delete  # just in case

      update-java-version "1.8"
      update-pkg-version "${src.rev}-autofirma-nix"
      update-dependency-version-by-groupId "es.gob.afirma.lib" "${src.rev}-autofirma-nix"
      reset-project-build-timestamp
      pin-default-plugin-versions
      pin-dependency-versions "${builtins.toFile "maven-dependency-versions.json" (builtins.toJSON maven-dependency-versions)}" "autofirma.clienteafirma.dependencies.clienteafirma-external"
    '';

    installPhase = ''
      mkdir -p $out/
      cp -R . $out/
    '';

    dontFixup = true;
  };

  clienteafirma-external-dependencies = stdenv.mkDerivation {
    name = "${name}-dependencies";

    src = clienteafirma-external-src;

    nativeBuildInputs = [
      maven
    ];

    buildPhase = ''
      runHook preBuild
      set -o pipefail

      mkdir -p $out/.m2/repository

      # Maven 3.10 (resolver 2) collects dependencies breadth-first and skips
      # the poms of conflict losers; force the depth-first collector of Maven
      # 3.9 so the downloaded repository does not depend on the Maven version.
      # dependency:list records the exact resolved versions (including
      # transitive ones) so update-fixed-output-derivations can capture them.
      # It runs inline with package so reactor siblings resolve; the list is
      # read from stdout because -DoutputFile drops modules in a reactor.
      mvn clean package dependency:list dependency:go-offline -Dmaven.repo.local=$out/.m2/repository -DskipTests -Daether.dependencyCollector.impl=df | tee /dev/stderr | grep -E ':[a-zA-Z0-9._-]+:jar:[a-zA-Z0-9._-]+:(compile|runtime|test|provided)' > $out/resolved-dependencies.txt

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      rm -rf $out/.m2/repository/es/gob/afirma/lib

      find $out -type f \( \
        -name \*.lastUpdated \
        -o -name resolver-status.properties \
        -o -name _remote.repositories \
        -o -name \*.md5 \
        -o -name \*.sha1 \) \
        -delete

      # Remote metadata is only needed to resolve version ranges, and it
      # changes with every upstream release.  Resolved versions are pinned
      # from maven-dependency-versions.lock, so no ranges remain.
      find $out -type f -name 'maven-metadata-*.xml' -not -name maven-metadata-local.xml -delete

      # Written by Maven 3.10 (resolver 2): remote prefix lists and lock files
      rm -rf $out/.m2/repository/.meta $out/.m2/repository/.locks

      runHook postInstall
    '';

    dontFixup = true;
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = maven-dependencies-hash;
  };
in
  stdenv.mkDerivation {
    pname = "${name}-m2-repository";
    version = src.rev;

    groupId = "es.gob.afirma.lib";
    finalVersion = "${src.rev}-autofirma-nix";
    passthru.dependencyFod = clienteafirma-external-dependencies;

    src = clienteafirma-external-src;

    nativeBuildInputs = [
      maven
      rsync
      pom-tools
    ];

    buildPhase = ''
      cp -r ${clienteafirma-external-dependencies}/.m2 . && chmod -R u+w .m2

      mvn --offline package -Dmaven.repo.local=.m2/repository -DskipTests
    '';

    installPhase = ''
      mkdir -p $out/.m2/repository/es/gob/afirma/lib

      rm -rf .m2/repository/es/gob/afirma/lib

      mvn --offline install -Dmaven.repo.local=.m2/repository -DskipTests

      rsync -av .m2/repository/es/gob/afirma/lib $out/.m2/repository/es/gob/afirma/

      find $out -type f \( \
        -name \*.lastUpdated \
        -o -name resolver-status.properties \
        -o -name _remote.repositories \) \
        -delete
    '';

    fixupPhase = ''
      cd $out/.m2/repository
      reset-maven-metadata-local-timestamp
    '';

    meta = with lib; {
      description = "External libraries used by Cliente @firma";
      homepage = "https://github.com/ctt-gob-es/clienteafirma-external";
      license = with licenses; [gpl2Only eupl11];
      maintainers = with maintainers; [nilp0inter];
      platforms = platforms.linux;
    };
  }
