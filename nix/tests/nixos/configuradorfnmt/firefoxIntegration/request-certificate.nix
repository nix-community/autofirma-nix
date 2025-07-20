{ self, pkgs, lib }:
pkgs.nixosTest {
  name = "test-nixos-configuradorfnmt-firefoxIntegration-request-certificate";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      self.nixosModules.configuradorfnmt
      (modulesPath + "./../tests/common/x11.nix")
      ../../../_common/nixos/stateVersion.nix
    ];

    programs.configuradorfnmt.enable = true;
    programs.configuradorfnmt.firefoxIntegration.enable = true;

    programs.firefox.enable = true;

    # Allow Firefox to open AutoConfig settings without user interaction
    programs.firefox.autoConfig = ''
      pref("network.protocol-handler.expose.fnmtcr", true);
    '';

    environment.systemPackages = [
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

        ${lib.getExe config.programs.firefox.package} /tmp/configuradorfnmt.html
      '')
    ];
  };

  testScript = ''
    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    # Open firefox and allow it to import AutoConfig settings
    machine.execute("firefox >&2 &")
    machine.wait_for_window("Mozilla Firefox")
    machine.sleep(5)

    # Open an fnmtcr:// URL in Firefox
    machine.execute("open-configuradorfnmt-via-firefox")

    # Configurador FNMT-RCM should open automatically
    machine.wait_for_window('Uso de tarjeta criptográfica inteligente', 30)
    machine.screenshot("screen")
  '';
}
