{ self, pkgs, home-manager, lib }:
pkgs.nixosTest {
  name = "test-hm-as-nixos-module-autofirma-firefoxIntegration-protocol-handler";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      (modulesPath + "./../tests/common/x11.nix")
      ../../../../_common/hm-as-nixos-module/autofirma-user.nix
    ];

    home-manager.users.autofirma-user = {config, ... }: {
      imports = [
        self.homeManagerModules.autofirma
      ];
      programs.firefox.enable = true;
      programs.firefox.profiles.default.id = 0;
      programs.firefox.profiles.default.settings."network.protocol-handler.expose.afirma" = true;

      programs.autofirma.enable = true;
      programs.autofirma.firefoxIntegration.profiles.default.enable = true;

      home.packages = [
        (pkgs.writeScriptBin "open-autofirma-via-firefox" ''
          cat <<'EOF' > /tmp/autofirma.html
          <html>
            <head>
              <meta http-equiv="refresh" content="0;url=afirma://sign?op=sign&algorithm=SHA256withRSA&format=AUTO">
            </head>
            <body>
              <p>Redirecting to autofirma...</p>
            </body>
          </html>
          EOF

          ${lib.getExe config.programs.firefox.finalPackage} /tmp/autofirma.html
        '')
      ];
    };
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    # Authorize root (testScript user) to connect to the user's X server
    # machine.succeed(user_cmd("xhost +local:"))

    # Open firefox and allow it to import AutoConfig settings
    machine.execute(user_cmd("firefox >&2 &"))
    machine.wait_for_window("Mozilla Firefox")
    machine.sleep(5)

    # Open an afirma:// URL in Firefox
    machine.execute(user_cmd("open-autofirma-via-firefox"))

    # Wait for the AutoFirma window to appear
    machine.wait_for_window('Seleccione el fichero de datos a firmar', 30)
    machine.sleep(5)
    machine.screenshot("screen")
  '';
}
