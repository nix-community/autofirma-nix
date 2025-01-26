{
  python3Packages,
  openssl,
  chromedriver,
  chromium,
  nix,
  makeWrapper
}:
python3Packages.buildPythonApplication {
  name = "download-url-linked-CAs";
  nativeBuildInputs = [
    makeWrapper
  ];
  propagatedBuildInputs = [
    python3Packages.requests
    python3Packages.beautifulsoup4
    python3Packages.selenium
    openssl
    nix
    chromedriver
    chromium
  ];
  dontUnpack = true;
  format = "other";
  installPhase = ''
    install -Dm755 ${./download-url-linked-CAs.py} $out/bin/download-url-linked-CAs
    # makewrapper that addes the path to cromedriver to the var CHROMEDRIVER_PATH
    wrapProgram $out/bin/download-url-linked-CAs \
      --set "CHROMEDRIVER_PATH" "${chromedriver}/bin/chromedriver"
  '';
}
