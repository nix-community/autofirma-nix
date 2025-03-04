{ stdenv, python3, pandoc, makeWrapper, lib }:

stdenv.mkDerivation {
  name = "properties-to-json";
  dontUnpack = true;  # No archive to unpack (using a single script file)

  # Dependencies
  nativeBuildInputs = [ makeWrapper ];        # needed for makeWrapper utility
  buildInputs = [ python3 pandoc ];           # python3 interpreter and pandoc at runtime

  installPhase = ''
    # Install the Python script to $out/bin and make it executable
    install -Dm755 ${./properties-to-json.py} $out/bin/properties-to-json

    # Patch the shebang to use the exact python3 path from Nix store
    patchShebangs $out/bin

    # Wrap the script to include pandoc in PATH at runtime
    wrapProgram $out/bin/properties-to-json \
      --prefix PATH : ${pandoc}/bin
  '';
}
