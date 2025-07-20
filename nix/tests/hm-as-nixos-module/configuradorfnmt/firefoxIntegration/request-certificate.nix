{ self, pkgs, home-manager, lib }:
pkgs.nixosTest {
  name = "test-hm-as-nixos-module-configuradorfnmt-firefoxIntegration-request-certificate";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      (modulesPath + "./../tests/common/x11.nix")
      ../../../_common/hm-as-nixos-module/autofirma-user.nix
    ];

    home-manager.users.autofirma-user = {config, ... }: {
      imports = [
        self.homeManagerModules.configuradorfnmt
      ];
      programs.firefox.enable = true;
      programs.firefox.profiles.default.id = 0;
      programs.firefox.profiles.default.settings."network.protocol-handler.expose.fnmtcr" = true;

      programs.configuradorfnmt.enable = true;
      programs.configuradorfnmt.firefoxIntegration.profiles.default.enable = true;

      home.packages = [
        (pkgs.writeScriptBin "open-configuradorfnmt-via-firefox" ''
          cat <<'EOF' > /tmp/configuradorfnmt.html
          <html>
            <head>
              <meta http-equiv="refresh" content="0;url=fnmtcr://request?fileid=0">
            </head>
            <body>
              <p>Redirecting to configuradorfnmt...</p>
            </body>
          </html>
          EOF

          ${lib.getExe config.programs.firefox.finalPackage} /tmp/configuradorfnmt.html
        '')
      ];
    };
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    # Open firefox and allow it to import AutoConfig settings
    machine.execute(user_cmd("firefox >&2 &"))
    machine.wait_for_window("Mozilla Firefox")
    machine.sleep(5)

    # Open an fnmtcr:// URL in Firefox
    machine.execute(user_cmd("open-configuradorfnmt-via-firefox"))

    # Wait for the ConfiguradorFNMT-RCM window to appear
    machine.wait_for_window('Uso de tarjeta criptográfico inteligente', 30)
    machine.sleep(5)
    machine.screenshot("screen")
  '';
}

