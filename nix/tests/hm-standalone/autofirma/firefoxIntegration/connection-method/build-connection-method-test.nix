{ testName, jsTestFile }:
{ self, pkgs, system, home-manager, lib }:
let
  testCerts = pkgs.callPackage ../../../../_common/pkgs/test_certs.nix {};
  stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
  homeManagerStandaloneConfiguration = systemConfig: home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      self.homeManagerModules.autofirma
      {
        home.username = "autofirma-user";
        home.homeDirectory = "/home/autofirma-user";
        home.stateVersion = "${stateVersion}";

        home.file.cabundle.text = systemConfig.environment.etc."ssl/certs/ca-certificates.crt".source;
        
        programs.autofirma.enable = true;
        programs.autofirma.truststore.package = self.packages."${system}".autofirma-truststore.override {
          caBundle = systemConfig.environment.etc."ssl/certs/ca-certificates.crt".source;
          govTrustedCerts = systemConfig.security.pki.certificateFiles;
        };
        programs.autofirma.firefoxIntegration.profiles.default.enable = true;

        programs.firefox.enable = true;
        programs.firefox.profiles.default.id = 0;
        # Allow Firefox to open AutoConfig settings without user interaction
        programs.firefox.profiles.default.settings."network.protocol-handler.expose.afirma" = true;
      }
    ];
  };
in
pkgs.nixosTest {
  name = testName;
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      (modulesPath + "./../tests/common/x11.nix")
      ../../../../_common/tests/autofirma_test_server
      ../../../../_common/hm-standalone/autofirma-user.nix
    ];

    environment.systemPackages = with pkgs; [
      (homeManagerStandaloneConfiguration config).activationPackage
      nss.tools
    ];

    autofirma-test-server.jsTestFile = jsTestFile;

    system.stateVersion = stateVersion;
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()
    machine.succeed(user_cmd('xhost +SI:localuser:root'))

    machine.succeed(user_cmd('home-manager-generation'))

    machine.wait_for_open_port(port=443)

    profile_dir = "default"
    machine.execute(user_cmd("firefox >&2 &"))

    machine.wait_for_file(f"/home/autofirma-user/.mozilla/firefox/{profile_dir}/cert9.db")
    machine.wait_for_file(f"/home/autofirma-user/.mozilla/firefox/{profile_dir}/key4.db")
    machine.sleep(5)

    machine.succeed(user_cmd(f'pk12util -i ${testCerts}/ciudadano_scard_act.p12 -d sql:/home/autofirma-user/.mozilla/firefox/{profile_dir} -W ""'))

    machine.succeed("rm -f /tmp/test_output.txt")
    machine.sleep(5)

    # Open firefox and allow it to import AutoConfig settings
    machine.execute(user_cmd("firefox --new-tab https://autofirma-nix.com/index.php >&2 &"))

    machine.wait_for_file("/tmp/test_output.txt")
    machine.sleep(5)
    machine.succeed("grep 'Signature Successful:' /tmp/test_output.txt")

  '';
}


