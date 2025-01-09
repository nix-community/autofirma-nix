{ self, pkgs, lib }:
let
  stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
in

pkgs.nixosTest {
  name = "test-nixos-module-dnieremote-config-jumpintro-usb";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      self.nixosModules.dnieremote
      (modulesPath + "./../tests/common/x11.nix")
    ];

    programs.dnieremote.enable = true;
    programs.dnieremote.jumpIntro = "usb";

    system.stateVersion = stateVersion;
  };

  testScript = ''
    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    machine.execute("dnieremotewizard >&2 &")

    # Wait for the wizard to start and jump into the usb screen and fail due to no usb device
    machine.wait_for_window('Finalización', 30)
    machine.sleep(5)
    machine.screenshot("screen")
  '';
}

