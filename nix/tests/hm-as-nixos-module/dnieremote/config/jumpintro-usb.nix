{ self, pkgs, home-manager, lib }:
let
  stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
in

pkgs.nixosTest {
  name = "test-hm-as-nixos-module-dnieremote-config-jumpintro-usb";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      home-manager.nixosModules.home-manager
      (modulesPath + "./../tests/common/x11.nix")
    ];

    test-support.displayManager.auto.user = "autofirma-nix-user";

    users.users.autofirma-nix-user = {
      isNormalUser = true;
    };

    home-manager.users.autofirma-nix-user = {config, ... }: {
      imports = [
        self.homeManagerModules.dnieremote
      ];

      programs.dnieremote.enable = true;
      programs.dnieremote.jumpIntro = "usb";

      home.stateVersion = stateVersion;
    };

    environment.systemPackages = with pkgs; [
      xorg.xhost.out
    ];
    system.stateVersion = stateVersion;
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-nix-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    # Authorize root (testScript user) to connect to the user's X server
    machine.succeed(user_cmd("xhost +local:"))

    machine.execute(user_cmd("dnieremotewizard >&2 &"))

    # Wait for the wizard to start and jump into the usb screen and fail due to no usb device
    machine.wait_for_window('Finalización', 30)
    machine.sleep(5)
    machine.screenshot("screen")
  '';
}

