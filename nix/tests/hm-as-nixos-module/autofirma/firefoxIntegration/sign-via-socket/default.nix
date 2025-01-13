{ self, pkgs, home-manager, lib }:
let
  testCerts = pkgs.callPackage ../../../../_common/pkgs/test_certs.nix {};
in
pkgs.nixosTest {
  name = "test-hm-as-nixos-module-autofirma-firefoxIntegration-sign-via-socket";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      (modulesPath + "./../tests/common/x11.nix")
      ../../../../_common/tests/autofirma_test_server
      ../../../../_common/hm-as-nixos-module/autofirma-user.nix
    ];

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
    };

    environment.systemPackages = with pkgs; [
      nss.tools
    ];

    autofirma-test-server.jsTestsPath = ./js_tests;
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()

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
