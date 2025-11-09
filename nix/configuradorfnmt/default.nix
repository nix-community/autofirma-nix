{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  temurin-jre-bin-25,
  runtimeShell,
  buildFHSEnv,
  makeDesktopItem,
}: let
  pname = "configuradorfnmt";
  version = "5.0.2";
  meta = with lib; {
    description = "Application to request the necessary keys for obtaining a digital certificate from the FNMT.";
    homepage = "https://www.sede.fnmt.gob.es/descargas/descarga-software/instalacion-software-generacion-de-claves";
    license = with licenses; []; # TODO
    maintainers = with maintainers; [nilp0inter];
    mainProgram = "configuradorfnmt";
    platforms = platforms.linux;
  };
  thisPkg = stdenv.mkDerivation {
    inherit meta;
    name = "configuradorfnmt-pkg";
    version = version;

    src = fetchurl {
      url = "https://descargas.cert.fnmt.es/Linux/${pname}_${version}.amd64.deb";
      hash = "sha256-+j/Fj5JwRtPozZLzZkc1RX1J9vRqDymIq/CzwLQjraY=";
    };

    buildInputs = [
      dpkg
    ];

    unpackCmd = "dpkg-deb -x $src .";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/configuradorfnmt $out/share
      cp -r share/doc $out/share
      cp lib/configuradorfnmt/*.* $out/lib/configuradorfnmt
      runHook postInstall
    '';

    postInstall = ''
      mkdir -p $out/bin
      cat > $out/bin/configuradorfnmt <<EOF
      #!${runtimeShell}
      ${temurin-jre-bin-25}/bin/java -classpath $out/lib/configuradorfnmt/configuradorfnmt.jar:$out/lib/configuradorfnmt/bcpkix-fips.jar:$out/lib/configuradorfnmt/bc-fips.jar es.gob.fnmt.cert.certrequest.CertRequest \$*
      EOF
      chmod +x $out/bin/configuradorfnmt
    '';
  };
  desktopItem = makeDesktopItem {
    name = pname;
    exec = "${pname} %u";
    icon = "${thisPkg}/lib/${pname}/${pname}.png";
    desktopName = "Configurador FNMT";
    genericName = "Configurador FNMT";
    categories = ["Office" "X-Utilities"];
    mimeTypes = ["x-scheme-handler/fnmtcr"];
  };
in
  buildFHSEnv {
    name = pname;
    inherit meta;
    targetPkgs = pkgs: [
      pkgs.firefox
      pkgs.jre
      pkgs.nss
    ];
    runScript = lib.getExe thisPkg;
    extraInstallCommands = ''
      mkdir -p "$out/share/applications"
      cp "${desktopItem}/share/applications/"* $out/share/applications

      mkdir -p $out/etc/firefox/pref
      cat > $out/etc/firefox/pref/configuradorfnmt.js <<EOF
      pref("network.protocol-handler.app.fnmtcr","$out/bin/configuradorfnmt");
      pref("network.protocol-handler.warn-external.fnmtcr",false);
      pref("network.protocol-handler.external.fnmtcr",true);
      EOF
    '';
  }
