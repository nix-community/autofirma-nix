{
  lib,
  stdenv,
  fetchzip,
  dpkg,
  autoPatchelfHook,
  gtkmm3,
  atkmm,
  glibmm,
  gtk3,
  pango,
  at-spi2-atk,
  cairo,
  openssl_1_1,
  android-tools,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  name = "dnieremote";
  version = "1.0-5";
  src = fetchzip {
    url = "https://www.dnielectronico.es/descargas/Apps/DNIeRemote_${version}_amd64.zip";
    hash = "sha256-NLIbgLknfHq6volGv9X3mBgIAdpcvnAo8fMBDeIGSQQ=";
    stripRoot = false;
  };
  buildInputs = [
    dpkg
    gtkmm3
    atkmm
    glibmm
    gtk3
    pango
    at-spi2-atk
    cairo
    openssl_1_1
    makeWrapper
  ];
  nativeBuildInputs = [
    autoPatchelfHook
  ];
  propagatedBuildInputs = [
    android-tools
  ];
  unpackCmd = "dpkg-deb -x $src/DNIeRemoteSetup_${version}_amd64.deb .";
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r bin local/lib share $out
    runHook postInstall
  '';
  postFixup = ''
    substituteInPlace $out/share/applications/DNIeRemoteWizard.desktop \
      --replace "Exec=dnieremotewizard" "Exec=$out/bin/dnieremotewizard"

    wrapProgram $out/bin/dnieremotewizard \
      --set PATH ${lib.makeBinPath [
      android-tools
    ]}
  '';
  meta = with lib; {
    description = "Enables NFC-based DNIe 3.0 reading for PCs, offering digital authentication for Spain's electronic administration services";
    homepage = "https://www.dnielectronico.es/PortalDNIe/PRF1_Cons02.action?pag=REF_1015&id_menu=65";
    license = with licenses; []; # TODO: find out
    maintainers = with maintainers; [nilp0inter];
    mainProgram = "dnieremotewizard";
    platforms = platforms.linux;
  };
}
