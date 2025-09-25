{ self, pkgs, home-manager, lib }:
pkgs.nixosTest {
  name = "test-hm-as-nixos-module-autofirma-librewolfIntegration-protocol-handler";
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
      programs.librewolf.enable = true;
      programs.librewolf.profiles.default.id = 0;
      programs.librewolf.profiles.default.settings."network.protocol-handler.expose.afirma" = true;

      programs.autofirma.enable = true;
      programs.autofirma.librewolfIntegration.profiles.default.enable = true;

      home.packages = [
        (pkgs.writeScriptBin "open-autofirma-via-librewolf" ''
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

          ${lib.getExe config.programs.librewolf.finalPackage} /tmp/autofirma.html
        '')
      ];
    };
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    # Open librewolf and allow it to import AutoConfig settings
    machine.execute(user_cmd("librewolf >&2 &"))
    machine.wait_for_window("LibreWolf")
    machine.sleep(5)

    # Open an afirma:// URL in Librewolf
    machine.execute(user_cmd("open-autofirma-via-librewolf"))

    # Wait for the AutoFirma window to appear
    machine.wait_for_window('Seleccione el fichero de datos a firmar', 30)
    machine.sleep(5)
    machine.screenshot("screen")
  '';
}
