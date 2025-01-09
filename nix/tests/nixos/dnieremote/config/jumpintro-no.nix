{ self, pkgs, lib }:
let
  stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
in

pkgs.nixosTest {
  name = "test-nixos-module-dnieremote-config-jumpintro-no";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      self.nixosModules.dnieremote
      (modulesPath + "./../tests/common/x11.nix")
    ];

    programs.dnieremote.enable = true;
    programs.dnieremote.jumpIntro = "no";

    system.stateVersion = stateVersion;
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

