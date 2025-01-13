{ self, pkgs, lib }:
pkgs.nixosTest {
  name = "test-nixos-autofirma-firefoxIntegration-sign-document";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      self.nixosModules.autofirma
      (modulesPath + "./../tests/common/x11.nix")
      ../../../_common/nixos/stateVersion.nix
    ];

    programs.autofirma.enable = true;
    programs.autofirma.firefoxIntegration.enable = true;

    programs.firefox.enable = true;

    # Allow Firefox to open AutoConfig settings without user interaction
    programs.firefox.autoConfig = ''
      pref("network.protocol-handler.expose.afirma", true);
    '';

    environment.systemPackages = [
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

        ${lib.getExe config.programs.firefox.package} /tmp/autofirma.html
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

    # Open an afirma:// URL in Firefox
    machine.execute("open-autofirma-via-firefox")

    # Wait for the AutoFirma window to appear
    machine.wait_for_window('Seleccione el fichero de datos a firmar', 30)
    machine.screenshot("screen")
  '';
}
