{ self, pkgs }:
pkgs.nixosTest {
  name = "test-nixos-module-dnieremote-config-jumpintro-no";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      self.nixosModules.dnieremote
      (modulesPath + "./../tests/common/x11.nix")
      ../../../_common/nixos/stateVersion.nix
    ];

    programs.dnieremote.enable = true;
    programs.dnieremote.jumpIntro = "no";
  };

  testScript = ''
    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    machine.execute("dnieremotewizard >&2 &")

    # Wait for the wizard to start and present the introduction screen
    machine.wait_for_window('Introducción', 30)
    machine.sleep(5)
    machine.screenshot("screen")
  '';
}

