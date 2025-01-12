{ self, pkgs, home-manager, lib }:
let
  stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
  testCerts = pkgs.stdenv.mkDerivation {
    name = "autofirma-nix-test-certs";
    src = pkgs.fetchzip {
      url = "https://www.izenpe.eus/contenidos/informacion/cas_izenpe/es_cas/adjuntos/Kit_certificados_ficticios_PRODUCCION_Izenpe.zip";
      stripRoot = false;
      hash = "sha256-21aKv/XBudooPVmdIw2GkzlqxwieECAA9y/0VIWtLOU=";
    };
    buildInputs = [ pkgs.unzip pkgs.openssl ];
    phases = "installPhase";
    installPhase = ''
      mkdir -p $out
      openssl pkcs12 -in "$src/ciudadano_scard_act.p12" -nocerts -nodes -passin "file:$src/pass.txt" -out private_key.pem
      openssl pkcs12 -export -out "$out/ciudadano_scard_act.p12" -inkey private_key.pem -in "$src/ciudadano_scard_act.cer" -passout pass:

      openssl pkcs12 -in "$src/ciudadano_scard_rev.p12" -nocerts -nodes -passin "file:$src/pass.txt" -out private_key.pem
      openssl pkcs12 -export -out "$out/ciudadano_scard_rev.p12" -inkey private_key.pem -in "$src/ciudadano_scard_rev.cer" -passout pass:
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
      keyUsage = keyEncipherment, dataEncipherment
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
in
pkgs.nixosTest {
  name = "test-hm-as-nixos-module-autofirma-firefoxIntegration-sign-via-socket";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      (modulesPath + "./../tests/common/x11.nix")
    ];

    test-support.displayManager.auto.user = "autofirma-user";

    users.users.autofirma-user = {
      isNormalUser = true;
    };

    home-manager.users.autofirma-user = {config, ... }: {
      imports = [
        self.homeManagerModules.autofirma
      ];

      programs.autofirma.enable = true;
      programs.autofirma.firefoxIntegration.profiles.default.enable = true;

      programs.firefox.enable = true;
      programs.firefox.profiles.default.id = 0;
      # Allow Firefox to open AutoConfig settings without user interaction
      programs.firefox.profiles.default.settings."network.protocol-handler.expose.afirma" = true;

      home.stateVersion = stateVersion;
    };

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

    services.caddy.enable = true;
    services.caddy.virtualHosts."autofirma-nix.com".extraConfig = ''
          root * ${./www}
          php_fastcgi unix/${config.services.phpfpm.pools.autofirma-nix-tests.socket}
          file_server
          tls ${autofirma-nix-test-certs}/autofirma-nix.com.crt ${autofirma-nix-test-certs}/autofirma-nix.com.key
    '';

    security.pki.certificateFiles = [
      "${autofirma-nix-test-certs}/autofirma-nix.ca.crt"
    ];

    environment.systemPackages = with pkgs; [
      nss.tools
      xorg.xhost.out
    ];

    system.stateVersion = stateVersion;
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    # Authorize root (testScript user) to connect to the user's X server
    machine.succeed(user_cmd("xhost +local:"))

    machine.wait_for_open_port(port=443)

    profile_dir = "default"
    machine.execute(user_cmd("firefox >&2 &"))

    machine.wait_for_file(f"/home/autofirma-user/.mozilla/firefox/{profile_dir}/cert9.db")
    machine.wait_for_file(f"/home/autofirma-user/.mozilla/firefox/{profile_dir}/key4.db")
    machine.sleep(3)

    machine.succeed(user_cmd(f'pk12util -i ${testCerts}/ciudadano_scard_act.p12 -d sql:/home/autofirma-user/.mozilla/firefox/{profile_dir} -W ""'))

    machine.succeed(user_cmd("autofirma-setup"))

    for testfile in ("test_websocket", "test_xhr"):
      machine.succeed("rm -f /tmp/test_output.txt")

      # Open firefox and allow it to import AutoConfig settings
      machine.execute(user_cmd(f"firefox --new-tab https://autofirma-nix.com/index.php?test={testfile}.js >&2 &"))

      machine.wait_for_file("/tmp/test_output.txt")
      machine.sleep(3)
      machine.succeed("grep 'Signature Successful:' /tmp/test_output.txt")

  '';
}
