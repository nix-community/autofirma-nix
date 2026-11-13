{
  lib,
  stdenv,
  writers,
  buildFHSEnv,
  jre,
  makeDesktopItem,
  makeWrapper,
  maven,
  nss,
  firefox,
  pom-tools,
  properties-to-json,
  jmulticard,
  clienteafirma-external,
  autofirma-truststore,
  rsync,
  src,
  maven-dependencies-hash ? "",
  maven-dependency-versions ? {},
  disableJavaVersionCheck ? true,
  disableAutoFirmaVersionCheck ? true,
  darkModeFix ? true,
}: let
  name = "autofirma";

  clienteafirma-src = stdenv.mkDerivation {
    name = "clienteafirma-src";

    inherit src;

    nativeBuildInputs = [pom-tools];

    patches =
      [
        ./patches/clienteafirma/pr-367.patch
        ./patches/clienteafirma/etc_config.patch
        ./patches/clienteafirma/aarch64_elf.patch  # Until https://github.com/ctt-gob-es/clienteafirma/pull/435 gets merged
      ]
      ++ (lib.optional disableJavaVersionCheck [
        ./patches/clienteafirma/dont_check_java_version.patch
      ])
      ++ (lib.optional darkModeFix [
        ./patches/clienteafirma/dark_mode_fix.patch
      ]);

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/
      cp -R . $out/
    '';

    postPatch = let
      javaVersion = "17";
      srcVersion = "${src.rev}-autofirma-nix";
      javadocVersion = "3.11.2";
      xmlDocletVersion = "2.0.3";
      pomRules = writers.writeJSON "pom-rules.json" {
        inherit javaVersion;
        pkgVersion = srcVersion;
        # Point the external dependencies and the reactor modules at the
        # versions we build, plus the websocket version the installer expects.
        dependencyVersions = {
          ${clienteafirma-external.groupId} = clienteafirma-external.finalVersion;
          ${jmulticard.groupId} = jmulticard.finalVersion;
          "es.gob.afirma" = srcVersion;
          "org.java-websocket" = "1.6.0";
        };
        # Drop server modules that are not needed in the build.
        removeProfileModules = {
          env-install = [
            "afirma-server-triphase-signer"
            "afirma-signature-retriever"
            "afirma-signature-storage"
          ];
        };
        # Deterministic build timestamp.
        resetBuildTimestamp = true;
        # Pin transitive version ranges to the exact resolved versions from
        # maven-dependency-versions.lock, so the downloaded dependencies do not
        # drift with new upstream releases.  This is independent of the Maven
        # version: dependencyManagement forces the pinned versions under any
        # Maven.  Users on a different Maven supply their own FOD hashes via
        # lib.mkAutofirma; the version pins are reused as-is.
        pinDependencyVersions = maven-dependency-versions."autofirma.clienteafirma".versions or {};
        # Register the xmldoclet plugin for documentation generation.
        pluginVersions = [
          {
            groupId = "org.apache.maven.plugins";
            artifactId = "maven-javadoc-plugin";
            version = javadocVersion;
          }
        ];
        addXmlDoclet = {
          inherit javadocVersion xmlDocletVersion;
        };
      };
    in ''
      pom-tools ${pomRules}
    '';

    dontFixup = true;
  };

  clienteafirma-dependencies = stdenv.mkDerivation {
    name = "${name}-dependencies";

    src = clienteafirma-src;

    nativeBuildInputs = [
      maven
      rsync
    ];

    buildPhase = ''
      runHook preBuild
      set -o pipefail

      mkdir -p $out/.m2/repository

      rsync -av ${jmulticard}/.m2/repository/ \
                ${clienteafirma-external}/.m2/repository/ \
                $out/.m2/repository/

      chmod -R +w $out/.m2/repository

      # Some install modules are only declared in the dev profile but are
      # needed in the install profile.  We delete them later.
      # dependency:list records the exact resolved versions (including
      # transitive ones) so update-fixed-output-derivations can capture them.
      # It runs inline with install/go-offline so reactor siblings resolve; the
      # list is read from stdout because -DoutputFile drops modules in a reactor.
      mvn install dependency:list -Dmaven.repo.local=$out/.m2/repository -DskipTests -Denv=dev | tee /dev/stderr | grep -E ':[a-zA-Z0-9._-]+:jar:[a-zA-Z0-9._-]+:(compile|runtime|test|provided)' > $out/resolved-dependencies.txt
      mvn dependency:go-offline dependency:list -Dmaven.repo.local=$out/.m2/repository -DskipTests -Denv=install | tee /dev/stderr | grep -E ':[a-zA-Z0-9._-]+:jar:[a-zA-Z0-9._-]+:(compile|runtime|test|provided)' >> $out/resolved-dependencies.txt

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      rm -rf $out/.m2/repository/es/gob/afirma  # Remove the modules that should be compiled in the build derivation. See above.

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

  meta = with lib; {
    description = "Spanish Government digital signature tool";
    homepage = "https://firmaelectronica.gob.es/Home/Ciudadanos/Aplicaciones-Firma.html";
    license = with licenses; [gpl2Only eupl11];
    maintainers = with maintainers; [nilp0inter];
    mainProgram = "autofirma";
    platforms = platforms.linux;
  };

  autofirma-jar = stdenv.mkDerivation {
    pname = name;
    version = src.rev;

    src = clienteafirma-src;

    nativeBuildInputs = [
      maven
      rsync
      nss
      properties-to-json
    ];

    propagatedBuildInputs = [nss.tools];

    buildPhase = ''
      cp -r ${clienteafirma-dependencies}/.m2 .

      rsync -av ${jmulticard}/.m2/repository/ \
                ${clienteafirma-external}/.m2/repository/ \
                .m2/repository

      chmod -R u+w .m2

      mvn --offline install -Dmaven.repo.local=.m2/repository -DskipTests -Denv=dev  # As in the dependencies derivation, some modules are only declared in the dev profile
                                                                                     # but are needed in the install profile.
      mvn --offline package -Dmaven.repo.local=.m2/repository -DskipTests -Denv=install

      properties-to-json "$src/afirma-ui-simple-configurator-common/src/main/resources/properties/preferences.properties" afirma-ui-simple-configurator-common/target/javadoc.xml > preferences.json
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib/AutoFirma
      install -Dm644 afirma-simple/target/autofirma.jar $out/lib/AutoFirma
      install -Dm644 preferences.json $out/lib/AutoFirma/preferences.json

      runHook postInstall
    '';
  };

  thisPkg = stdenv.mkDerivation {
    name = "autofirma";

    src = clienteafirma-src;

    inherit meta;

    buildInputs = [
      autofirma-jar
      makeWrapper
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/bin

      cp -r afirma-simple-installer/linux/instalador_deb/src/usr/lib $out
      cp -r afirma-simple-installer/linux/instalador_deb/src/usr/share $out
      cp -r afirma-simple-installer/linux/instalador_deb/src/etc $out

      makeWrapper ${jre}/bin/java $out/bin/autofirma \
        --set AUTOFIRMA_AVOID_UPDATE_CHECK ${lib.boolToString disableAutoFirmaVersionCheck} \
        --add-flags "-Djavax.net.ssl.trustStore=${autofirma-truststore}" \
        --add-flags "-Djavax.net.ssl.trustStoreType=PKCS12" \
        --add-flags "-Djavax.net.ssl.trustStorePassword=autofirma" \
        --add-flags "-Djdk.tls.maxHandshakeMessageSize=65536" \
        --add-flags "-Djdk.gtk.version=3" \
        --add-flags "-Dswing.defaultlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel" \
        --add-flags "-Dswing.crossplatformlaf=com.sun.java.swing.plaf.gtk.GTKLookAndFeel" \
        --add-flags "-Dawt.useSystemAAFontSettings=lcd" \
        --add-flags "-Dswing.aatext=true" \
        --add-flags "-jar ${autofirma-jar}/lib/AutoFirma/autofirma.jar"

      substituteInPlace $out/etc/firefox/pref/AutoFirma.js \
        --replace-fail /usr/bin/autofirma $out/bin/autofirma
      
    '';

    passthru = {
      truststore = autofirma-truststore;
      jar = autofirma-jar;
      dependencies = {
        clienteafirma = clienteafirma-dependencies;
        jmulticard = jmulticard;
        clienteafirma-external = clienteafirma-external;
      };
      preferences = builtins.fromJSON (builtins.readFile "${autofirma-jar}/lib/AutoFirma/preferences.json");
    };
  };

  desktopItem = makeDesktopItem {
    name = "Autofirma";
    desktopName = "Autofirma";
    genericName = "Herramienta de firma";
    exec = "autofirma %u";
    icon = "${thisPkg}/lib/AutoFirma/AutoFirma.png";
    mimeTypes = ["x-scheme-handler/afirma"];
    categories = ["Office" "X-Utilities" "X-Signature" "Java"];
    startupNotify = true;
    startupWMClass = "autofirma";
  };
in
  buildFHSEnv {
    name = name;
    inherit meta;
    targetPkgs = pkgs: [
      firefox
      pkgs.nss
      pkgs.fontconfig
      pkgs.freetype
      pkgs.dejavu_fonts
      pkgs.liberation_ttf
    ];
    runScript = lib.getExe thisPkg;
    extraInstallCommands = ''
      mkdir -p "$out/share/applications"
      cp "${desktopItem}/share/applications/"* $out/share/applications

      mkdir -p $out/etc/firefox/pref
      ln -s ${thisPkg}/etc/firefox/pref/AutoFirma.js $out/etc/firefox/pref/AutoFirma.js
    '';
    extraBwrapArgs = [
      "--ro-bind-try /etc/Autofirma /etc/Autofirma"
    ];
    passthru = {
      clienteafirma = thisPkg;
    };
  }
