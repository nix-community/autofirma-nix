{ pkgs, lib, config, ... }:
let
  cfg = config.autofirma-test-server;
  autoscript = pkgs.stdenv.mkDerivation {
    pname = "AutoScript";
    version = "1-8-2-1";
    src = pkgs.fetchzip {
      url = "https://administracionelectronica.gob.es/ctt/resources/Soluciones/138/Descargas/AutoScript%20v1-8-2-1.zip?idIniciativa=138&idElemento=17573";
      extension = "zip";
      hash = "sha256-r8V+v5wCnjOGGFzgVW9+qIcVufimeXOmz085dhPoD80=";
    };
    phases = "installPhase";
    installPhase = ''
      mkdir -p $out
      cp -rv "$src/js" $out
    '';
  };
  autofirma-nix-test-certs = pkgs.stdenv.mkDerivation {
    name = "autofirma-nix-test-certs";
    buildInputs = [ pkgs.openssl ];
    phases = "installPhase";
    installPhase = ''
      mkdir -p $out
      cd $out

      cat > san.cnf <<EOF
      [req]
      distinguished_name = req_distinguished_name
      req_extensions = v3_req
      prompt = no

      [req_distinguished_name]
      CN = autofirma-nix.com

      [v3_req]
      keyUsage = keyEncipherment, dataEncipherment, digitalSignature
      extendedKeyUsage = serverAuth
      subjectAltName = @alt_names

      [alt_names]
      DNS.1 = autofirma-nix.com
      DNS.2 = www.autofirma-nix.com
      EOF

      # Step 1: Generate CA private key and certificate
      openssl genrsa -out autofirma-nix.ca.key 2048
      openssl req -x509 -new -nodes -key autofirma-nix.ca.key -sha256 -days 365 -out autofirma-nix.ca.crt -subj "/CN=Autofirma-Nix CA"

      # Step 2: Generate private key for the certificate
      openssl genrsa -out autofirma-nix.com.key 2048

      # Step 3: Create a certificate signing request (CSR)
      openssl req -new -key autofirma-nix.com.key -out autofirma-nix.com.csr -config san.cnf

      # Step 4: Sign the CSR with the CA to create the certificate
      openssl x509 -req -in autofirma-nix.com.csr -CA autofirma-nix.ca.crt -CAkey autofirma-nix.ca.key -CAcreateserial \
      -out autofirma-nix.com.crt -days 365 -sha256 -extensions v3_req -extfile san.cnf

      # Step 5: Verify the certificate (optional)
      openssl verify -CAfile autofirma-nix.ca.crt autofirma-nix.com.crt
    '';
  };
  afirma-server-triphase-signer = pkgs.stdenv.mkDerivation {
    name = "afirma-server-triphase-signer";
    version = "2.7.3";
    src = pkgs.fetchzip {
      url = "https://estaticos.redsara.es/comunes/autofirma/1/8/3/afirma-server-triphase-signer-2.7.3.zip";
      hash = "sha256-siEawCiqKVbAjP8ckw2deF506k/o9ErXlrTGaNWYNa0=";
    };
    phases = "installPhase";
    installPhase = ''
      mkdir -p $out/webapps
      cp -rv $src/* $out/webapps
    '';
  };
  afirma-signature-storage = pkgs.stdenv.mkDerivation {
    name = "afirma-signature-storage";
    src = pkgs.fetchzip {
      url = "https://administracionelectronica.gob.es/ctt/resources/Soluciones/138/Descargas/afirma-signature-storage.zip?idIniciativa=138&idElemento=11461";
      extension = "zip";
      hash = "sha256-lomELBI1gHom1CJL9xS6y2WeUO8VKzsbM7J7jSVsB9s=";
    };
    phases = "installPhase";
    installPhase = ''
      mkdir -p $out/webapps
      cp -rv $src/* $out/webapps
      '';
  };
  afirma-signature-retriever = pkgs.stdenv.mkDerivation {
    name = "afirma-signature-retriever";
    src = pkgs.fetchzip {
      url = "https://administracionelectronica.gob.es/ctt/resources/Soluciones/138/Descargas/afirma-signature-retriever.zip?idIniciativa=138&idElemento=11462";
      extension = "zip";
      hash = "sha256-W3NnHTi87sVeavv1JrOe2KeUxVW5FGbIAOwP6L4X9n0=";
    };
    phases = "installPhase";
    installPhase = ''
      mkdir -p $out/webapps
      cp -rv $src/* $out/webapps
      '';
  };
in

{
  options = {
    autofirma-test-server = {
      jsTestsPath = lib.mkOption {
        type = lib.types.path;
        description = "Path to the JavaScript tests";
      };
    };
  };
  config = {
    networking.hosts."127.0.0.1" = [ "autofirma-nix.com" ];

    services.phpfpm.pools.autofirma-nix-tests = {
      user = config.services.caddy.user;
      settings = {
        "pm" = "dynamic";
        "pm.max_children" = 75;
        "pm.start_servers" = 10;
        "pm.min_spare_servers" = 5;
        "pm.max_spare_servers" = 20;
        "pm.max_requests" = 500;
        "listen.owner" = config.services.caddy.user;
      };
    };
    systemd.services.phpfpm-autofirma-nix-tests.serviceConfig.PrivateTmp = lib.mkForce false;

    services.tomcat.enable = true;
    services.tomcat.webapps =  [
      afirma-server-triphase-signer
      afirma-signature-storage
      afirma-signature-retriever
      config.services.tomcat.package.webapps
    ];
    services.tomcat.virtualHosts = [
      { 
        name = "autofirma-auxiliary-services";
        aliases = [ "localhost:8080" "127.0.0.1:8080" ];
      }
    ];
    services.tomcat.logPerVirtualHost = true;
    services.tomcat.extraConfigFiles = let 
      tomcat-users = (pkgs.writeTextFile {
        name = "tomcat-users.xml";
        text = ''
          <tomcat-users>
              <role rolename="manager-gui"/>
              <role rolename="manager-script"/>
              <role rolename="manager-jmx"/>
              <role rolename="manager-status"/>

              <user username="admin"
                    password="admin"
                    roles="manager-gui,manager-script,manager-jmx,manager-status"/>
          </tomcat-users>
        '';
        destination = "/tomcat-users.xml";
      });
      in
      [
        "${tomcat-users}/tomcat-users.xml"
      ];

    services.caddy.enable = true;
    services.caddy.virtualHosts."autofirma-nix.com".extraConfig = ''
      tls ${autofirma-nix-test-certs}/autofirma-nix.com.crt ${autofirma-nix-test-certs}/autofirma-nix.com.key

      root * ${./www}

      php_fastcgi unix/${config.services.phpfpm.pools.autofirma-nix-tests.socket}

      handle_path /tests/* {
        root * ${cfg.jsTestsPath}
        file_server
      }

      handle_path /js/* {
        root * ${autoscript}/js
        file_server
      }

      handle /afirma-* {  
          reverse_proxy http://127.0.0.1:8080
      }

      file_server
    '';

    security.pki.certificateFiles = [
      "${autofirma-nix-test-certs}/autofirma-nix.ca.crt"
    ];
  };
}

