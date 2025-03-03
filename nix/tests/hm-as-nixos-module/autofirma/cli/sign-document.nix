{ self, pkgs, home-manager, lib }:
let
  openssl = lib.getExe pkgs.openssl;
in

pkgs.nixosTest {
  name = "test-hm-as-nixos-module-autofirma-firefoxIntegration-sign-document";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      (modulesPath + "./../tests/common/x11.nix")
      ../../../_common/hm-as-nixos-module/autofirma-user.nix
    ];

    home-manager.users.autofirma-user = {
      imports = [
        self.homeManagerModules.autofirma
      ];
      programs.autofirma.enable = true;
    };

    system.stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_x()

    machine.succeed(user_cmd('echo "NixOS Autofirma Sign Test" > document.txt'))
    machine.succeed(user_cmd('${openssl} req -x509 -newkey rsa:2048 -keyout private.key -out certificate.crt -days 365 -nodes -subj "/C=ES/O=TEST AUTOFIRMA NIX/OU=DNIE/CN=AC DNIE 004" -passout pass:1234'))
    machine.succeed(user_cmd('${openssl} pkcs12 -export -out certificate.p12 -inkey private.key -in certificate.crt -name "testcert" -password pass:1234'))

    machine.succeed(user_cmd('autofirma sign -store pkcs12:certificate.p12 -i document.txt -o document.txt.sign -filter alias.contains=testcert -password 1234 -xml'))
  '';
}
