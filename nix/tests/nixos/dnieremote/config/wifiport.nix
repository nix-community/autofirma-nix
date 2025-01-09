{ self, pkgs, lib }:
let
  stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
in

pkgs.nixosTest {
  name = "test-nixos-module-dnieremote-config-wifiport";
  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      self.nixosModules.dnieremote
      (modulesPath + "./../tests/common/x11.nix")
    ];

      programs.dnieremote.enable = true;
      programs.dnieremote.jumpIntro = "wifi";
      programs.dnieremote.wifiPort = 4444;
      programs.dnieremote.openFirewall = true;

      networking.firewall.enable = true;

    system.stateVersion = stateVersion;
  };

  testScript = ''
    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    bind_ip = machine.execute("ip -4 route get 1.1.1.1 | grep -oP '(?<=src )\d+(\.\d+){3}'")[1].rstrip('\n')

    machine.succeed("grep 'wifiport=4444;' /etc/dnieRemote/dnieRemote.cfg")

    # Wait for the wizard to start and jump into the wifi screen
    machine.execute("dnieremotewizard >&2 &")

    machine.wait_for_open_port(4444, bind_ip, 30)
  '';
}

