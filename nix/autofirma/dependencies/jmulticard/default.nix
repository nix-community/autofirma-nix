{
  lib,
  stdenv,
  fetchFromGitHub,
  maven,
  pom-tools,
  rsync,
  src,
  maven-dependencies-hash ? "",
}: let
  name = "jmulticard";

  # bcpkix-jdk18on 1.80 asks for bcutil-jdk18on [1.80,1.81).  Pin it to the
  # version that range resolves to today, so that Maven does not resolve it
  # against Maven Central's metadata, which changes with every release.
  bcutilVersion = "1.80.2";

  jmulticard-src = stdenv.mkDerivation {
    name = "${name}-src";

    inherit src;

    nativeBuildInputs = [
      pom-tools
    ];

    dontBuild = true;

    patchPhase = ''
      find . -name '*.jar' -delete  # just in case

      update-java-version "1.8"
      update-pkg-version "${src.rev}-autofirma-nix"
      update-dependency-version-by-groupId "es.gob.afirma.jmulticard" "${src.rev}-autofirma-nix"
      reset-project-build-timestamp
      pin-default-plugin-versions
      pin-managed-version dependency org.bouncycastle bcutil-jdk18on "${bcutilVersion}"
    '';

    installPhase = ''
      mkdir -p $out/
      cp -R . $out/
    '';

    dontFixup = true;
  };

  jmulticard-dependencies = stdenv.mkDerivation {
    name = "${name}-dependencies";

    src = jmulticard-src;

    nativeBuildInputs = [
      maven
    ];

    buildPhase = ''
      runHook preBuild

      mkdir -p $out/.m2/repository

      # Maven 3.10 (resolver 2) collects dependencies breadth-first and skips
      # the poms of conflict losers; force the depth-first collector of Maven
      # 3.9 so the downloaded repository does not depend on the Maven version.
      mvn clean package dependency:go-offline -Dmaven.repo.local=$out/.m2/repository -DskipTests -Daether.dependencyCollector.impl=df

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      rm -rf $out/.m2/respository/es/gob/afirma/jmulticard

      find $out -type f \( \
        -name \*.lastUpdated \
        -o -name resolver-status.properties \
        -o -name _remote.repositories \
        -o -name \*.md5 \
        -o -name \*.sha1 \) \
        -delete

      # Remote metadata is only needed to resolve version ranges, and it
      # changes with every upstream release.  Ranges are pinned in the poms.
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

    groupId = "es.gob.afirma.jmulticard";
    finalVersion = "${src.rev}-autofirma-nix";
    inherit bcutilVersion;

    src = jmulticard-src;

    nativeBuildInputs = [
      rsync
      maven
      pom-tools
    ];

    buildPhase = ''
      cp -r ${jmulticard-dependencies}/.m2 . && chmod -R u+w .m2

      mvn --offline package -Dmaven.repo.local=.m2/repository -DskipTests
    '';

    installPhase = ''
      mkdir -p $out/.m2/repository/es/gob/afirma/jmulticard

      rm -rf .m2/repository/es/gob/afirma/jmulticard

      mvn --offline install -Dmaven.repo.local=.m2/repository -DskipTests

      rsync -av .m2/repository/es/gob/afirma/jmulticard $out/.m2/repository/es/gob/afirma/

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
      description = "Capa abstracta de acceso a tarjetas inteligentes 100% java";
      homepage = "https://github.com/ctt-gob-es/jmulticard";
      license = with licenses; [gpl2Only eupl11];
      maintainers = with maintainers; [nilp0inter];
      platforms = platforms.linux;
    };
  }
