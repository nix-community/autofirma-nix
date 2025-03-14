{ testName, jsTestFile }:
{ self, pkgs, lib, system }:
let
  testCerts = pkgs.callPackage ../../../../_common/pkgs/test_certs.nix {};
in
pkgs.nixosTest {
  name = testName;
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      self.nixosModules.autofirma
      (modulesPath + "./../tests/common/x11.nix")
      ../../../../_common/tests/autofirma_test_server
      ../../../../_common/nixos/stateVersion.nix
    ];

    programs.autofirma.enable = true;
    programs.autofirma.truststore.package = self.packages."${system}".autofirma-truststore.override (old: {
      caBundle = config.environment.etc."ssl/certs/ca-certificates.crt".source;
      govTrustedCerts = old.govTrustedCerts ++ config.security.pki.certificateFiles;
    });

    programs.autofirma.firefoxIntegration.enable = true;

    programs.firefox.enable = true;

    # Allow Firefox to open AutoConfig settings without user interaction
    programs.firefox.autoConfig = ''
      pref("network.protocol-handler.expose.afirma", true);
    '';

    autofirma-test-server.jsTestFile = jsTestFile;

    environment.systemPackages = [
      pkgs.nss.tools
    ];

  };

  testScript = ''
    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    machine.wait_for_open_port(port=443)

    machine.succeed("firefox --headless --CreateProfile default")
    profile_dir = machine.succeed("grep -oP 'Path=\\K.*' ~/.mozilla/firefox/profiles.ini").rstrip("\n")
    machine.execute("firefox >&2 &")

    machine.wait_for_file(f"~/.mozilla/firefox/{profile_dir}/cert9.db")
    machine.wait_for_file(f"~/.mozilla/firefox/{profile_dir}/key4.db")
    machine.sleep(5)

    machine.succeed(f'pk12util -i ${testCerts}/ciudadano_scard_act.p12 -d sql:/root/.mozilla/firefox/{profile_dir} -W ""')
    machine.sleep(5)

    # Open firefox and allow it to import AutoConfig settings
    machine.execute("firefox --new-tab https://autofirma-nix.com/index.php >&2 &")

    machine.wait_for_file("/tmp/test_output.txt")
    machine.sleep(5)
    machine.succeed("grep 'Signature Successful:' /tmp/test_output.txt")

  '';
}
