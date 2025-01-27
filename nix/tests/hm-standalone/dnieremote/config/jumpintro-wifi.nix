{ self, pkgs, home-manager, lib }:
let
  stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
  homeManagerStandaloneConfiguration = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      self.homeManagerModules.dnieremote

      ({ config, ... }: {
        home.username = "autofirma-user";
        home.homeDirectory = "/home/autofirma-user";
        home.stateVersion = "${stateVersion}";

        programs.dnieremote.enable = true;
        programs.dnieremote.jumpIntro = "wifi";
      })
    ];
  };
in
pkgs.nixosTest {
  name = "test-hm-standalone-dnieremote-config-jumpintro-wifi";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      (modulesPath + "./../tests/common/x11.nix")
      ../../../_common/hm-standalone/autofirma-user.nix
    ];

    environment.systemPackages = [
      homeManagerStandaloneConfiguration.activationPackage
    ];

    system.stateVersion = stateVersion;
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()
    machine.succeed(user_cmd('xhost +SI:localuser:root'))

    machine.succeed(user_cmd('home-manager-generation'))

    machine.execute(user_cmd("dnieremotewizard >&2 &"))

    # Wait for the wizard to start and jump into the wifi screen
    machine.wait_for_window('Vinculación dispositivo y DNIe', 30)
    machine.sleep(5)
    machine.screenshot("screen")
  '';
}

