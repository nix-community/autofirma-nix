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
        programs.dnieremote.wifiPort = 4444;
      })
    ];
  };
in
pkgs.nixosTest {
  name = "test-hm-standalone-dnieremote-config-wifiport";
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

    bind_ip = machine.execute("ip -4 route get 1.1.1.1 | grep -oP '(?<=src )\d+(\.\d+){3}'")[1].rstrip('\n')

    machine.succeed("grep 'wifiport=4444;' /home/autofirma-user/dnieRemote.cfg")

    # Wait for the wizard to start and jump into the wifi screen
    machine.execute(user_cmd("dnieremotewizard >&2 &"))

    machine.wait_for_open_port(4444, bind_ip, 30)
  '';
}

