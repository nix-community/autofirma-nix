{
  lib,
  stdenv,
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
        ./patches/clienteafirma/detect_java_version.patch
        ./patches/clienteafirma/pr-367.patch
        ./patches/clienteafirma/certutilpath.patch
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
    in
    ''
      # Update the version of the Java runtime to use
      update-java-version "${javaVersion}"

      # Update the version of the package to a custom one based on the revision we're building
      update-pkg-version "${srcVersion}"

      # Make sure the version of the external dependencies is the one we've built
      update-dependency-version-by-groupId "${clienteafirma-external.groupId}" "${clienteafirma-external.finalVersion}"
      update-dependency-version-by-groupId "${jmulticard.groupId}" "${jmulticard.finalVersion}"
      update-dependency-version-by-groupId "es.gob.afirma" "${srcVersion}"

      # Remove some modules that we don't need in the build
      remove-module-on-profile "env-install" "afirma-server-triphase-signer"
      remove-module-on-profile "env-install" "afirma-signature-retriever"
      remove-module-on-profile "env-install" "afirma-signature-storage"

      # For the build to be deterministic, we need to reset the project build timestamp
      reset-project-build-timestamp

      # Register the xmldoclet plugin in the pom.xml for documentation generation
      update-plugin-version-by-groupId "org.apache.maven.plugins" "maven-javadoc-plugin" "${javadocVersion}"
      add-xml-doclet-to-javadoc-plugin "${javadocVersion}" "${xmlDocletVersion}"

      substituteInPlace afirma-ui-simple-configurator/src/main/java/es/gob/afirma/standalone/configurator/ConfiguratorFirefoxLinux.java \
        --replace-fail '@certutilpath' '${nss.tools}/bin/certutil'
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

      mkdir -p $out/.m2/repository

      rsync -av ${jmulticard}/.m2/repository/ \
                ${clienteafirma-external}/.m2/repository/ \
                $out/.m2/repository/

      chmod -R +w $out/.m2/repository

      mvn install -Dmaven.repo.local=$out/.m2/repository -DskipTests -Denv=dev  # Some install modules are only declared in the dev profile
                                                                                # but are needed in the install profile.  We delete them later.
      mvn dependency:go-offline -Dmaven.repo.local=$out/.m2/repository -DskipTests -Denv=install

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      rm -rf $out/.m2/repository/es/gob/afirma  # Remove the modules that should be compiled in the build derivation. See above.

      find $out -type f \( \
        -name \*.lastUpdated \
        -o -name resolver-status.properties \
        -o -name _remote.repositories \) \
        -delete

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

      mvn --offline install -Dmaven.javadoc.skip=true -Dmaven.repo.local=.m2/repository -DskipTests -Denv=dev  # As in the dependencies derivation, some modules are only declared in the dev profile
                                                                                                               # but are needed in the install profile.
      mvn --offline package -Dmaven.repo.local=.m2/repository -DskipTests -Denv=install

      properties-to-json "$src/afirma-simple/src/main/resources/properties/preferences.properties" afirma-simple/target/javadoc.xml > preferences.json

    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib/AutoFirma
      install -Dm644 afirma-simple/target/AutoFirma.jar $out/lib/AutoFirma
      install -Dm644 afirma-ui-simple-configurator/target/AutoFirmaConfigurador.jar $out/lib/AutoFirma
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
        --add-flags "-jar ${autofirma-jar}/lib/AutoFirma/AutoFirma.jar"

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
    name = "AutoFirma";
    desktopName = "AutoFirma";
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
      "--ro-bind-try /etc/AutoFirma /etc/AutoFirma"
    ];
    passthru = {
      clienteafirma = thisPkg;
    };
  }
