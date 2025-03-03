{ self, pkgs, lib }:
let
  openssl = lib.getExe pkgs.openssl;
in

pkgs.nixosTest {
  name = "test-nixos-autofirma-cli-sign-document";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      self.nixosModules.autofirma
      (modulesPath + "./../tests/common/x11.nix")
      ../../../_common/nixos/stateVersion.nix
    ];

    programs.autofirma.enable = true;
  };

  testScript = ''
    machine.succeed('echo "NixOS Autofirma Sign Test" > document.txt')
    machine.succeed('${openssl} req -x509 -newkey rsa:2048 -keyout private.key -out certificate.crt -days 365 -nodes -subj "/C=ES/O=TEST AUTOFIRMA NIX/OU=DNIE/CN=AC DNIE 004" -passout pass:1234')
    machine.succeed('${openssl} pkcs12 -export -out certificate.p12 -inkey private.key -in certificate.crt -name "testcert" -password pass:1234')

    machine.wait_for_x()

    machine.succeed('autofirma sign -store pkcs12:certificate.p12 -i document.txt -o document.txt.sign -filter alias.contains=testcert -password 1234 -xml')
  '';
}
