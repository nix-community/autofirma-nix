{ self, pkgs, home-manager}:
pkgs.nixosTest {
  name = "test-hm-as-nixos-module-dnieremote-config-wifiport";
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
      programs.dnieremote.jumpIntro = "wifi";
      programs.dnieremote.wifiPort = 4444;
    };
  };

  testScript = ''
    def user_cmd(cmd):
      return f"su -l autofirma-user --shell /bin/sh -c $'export XDG_RUNTIME_DIR=/run/user/$UID ; {cmd}'"

    machine.wait_for_unit("default.target")
    machine.wait_for_x()

    bind_ip = machine.execute("ip -4 route get 1.1.1.1 | grep -oP '(?<=src )\d+(\.\d+){3}'")[1].rstrip('\n')

    machine.succeed("grep 'wifiport=4444;' /home/autofirma-user/dnieRemote.cfg")

    # Wait for the wizard to start and jump into the wifi screen
    machine.execute(user_cmd("dnieremotewizard >&2 &"))

    machine.wait_for_open_port(4444, bind_ip, 30)
  '';
}

