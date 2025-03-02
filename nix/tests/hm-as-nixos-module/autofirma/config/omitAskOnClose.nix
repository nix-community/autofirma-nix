{ self, pkgs, home-manager }:
pkgs.nixosTest {
  name = "test-hm-as-nixos-module-autofirma-config-omitAskOnClose";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      (modulesPath + "./../tests/common/x11.nix")
      ../../../_common/hm-as-nixos-module/autofirma-user.nix
    ];

    home-manager.users.autofirma-user = {config, ... }: {
      imports = [
        self.homeManagerModules.autofirma
      ];

      programs.autofirma.enable = true;
      programs.autofirma.config.omitAskOnClose = true;
    };
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    machine.execute(user_cmd("autofirma >&2 &"))

    machine.wait_for_window('AutoFirma\s.*', 30)
    machine.sleep(5)
    machine.send_key("alt-f4")
    machine.wait_until_succeeds(user_cmd('[ ! $(pgrep -x java) ]'), 30)
  '';
}


