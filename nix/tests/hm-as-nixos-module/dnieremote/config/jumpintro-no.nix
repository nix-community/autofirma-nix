{ self, pkgs, home-manager }:
pkgs.nixosTest {
  name = "test-hm-as-nixos-module-dnieremote-config-jumpintro-no";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      (modulesPath + "./../tests/common/x11.nix")
      ../../../_common/hm-as-nixos-module/autofirma-user.nix
    ];

    home-manager.users.autofirma-user = {config, ... }: {
      imports = [
        self.homeManagerModules.dnieremote
      ];

      programs.dnieremote.enable = true;
      programs.dnieremote.jumpIntro = "no";
    };
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    machine.execute(user_cmd("dnieremotewizard >&2 &"))

    # Wait for the wizard to start and present the introduction screen
    machine.wait_for_window('Introducción', 30)
    machine.sleep(5)
    machine.screenshot("screen")
  '';
}

