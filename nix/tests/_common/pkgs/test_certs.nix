{ stdenv, fetchzip, unzip, openssl }:
stdenv.mkDerivation {
  name = "autofirma-nix-test-certs";
  src = fetchzip {
    url = "https://www.izenpe.eus/contenidos/informacion/cas_izenpe/es_cas/adjuntos/Kit_certificados_ficticios_PRODUCCION_Izenpe.zip";
    stripRoot = false;
    hash = "sha256-21aKv/XBudooPVmdIw2GkzlqxwieECAA9y/0VIWtLOU=";
  };
  buildInputs = [ unzip openssl ];
  phases = "installPhase";
  installPhase = ''
    mkdir -p $out
    openssl pkcs12 -in "$src/ciudadano_scard_act.p12" -nocerts -nodes -passin "file:$src/pass.txt" -out private_key.pem
    openssl pkcs12 -export -out "$out/ciudadano_scard_act.p12" -inkey private_key.pem -in "$src/ciudadano_scard_act.cer" -passout pass:

    openssl pkcs12 -in "$src/ciudadano_scard_rev.p12" -nocerts -nodes -passin "file:$src/pass.txt" -out private_key.pem
    openssl pkcs12 -export -out "$out/ciudadano_scard_rev.p12" -inkey private_key.pem -in "$src/ciudadano_scard_rev.cer" -passout pass:
  '';
}
