# Home Manager with NixOS

If you're using Home Manager as a NixOS module and want a per-user AutoFirma setup, this approach provides fine-grained configuration for each user.

## Quick Start with Template

You can quickly get started with a fully configured template:

```bash
$ nix flake new --template github:nix-community/autofirma-nix#home-manager-nixos ./my-autofirma-system-with-hm
```

This creates a new directory with a complete flake configuration for Home Manager as a NixOS module with all available options.

## Minimal Configuration

First, make sure Home Manager is imported in your NixOS configuration:

```nix
{
  imports = [
    # Your other imports
    home-manager.nixosModules.home-manager
  ];
}
```

Then, configure AutoFirma for a specific user:

```nix
{
  home-manager.users.yourUsername = { config, pkgs, ... }: {
    imports = [
      autofirma-nix.homeManagerModules.default
    ];
    
    # Enable AutoFirma with Firefox integration
    programs.autofirma = {
      enable = true;
      firefoxIntegration.profiles = {
        default = {
          enable = true;
        };
      };
    };
    
    # DNIeRemote for using smartphone as DNIe reader
    programs.dnieremote = {
      enable = true;
    };
    # Note: The Android app may not be available on Google Play for modern devices.
    # See the troubleshooting guide for installation alternatives.

    # FNMT certificate configurator
    programs.configuradorfnmt = {
      enable = true;
      firefoxIntegration.profiles = {
        default = {
          enable = true;
        };
      };
    };
    
    # Configure Firefox
    programs.firefox = {
      enable = true;
      policies = {
        SecurityDevices = {
          "OpenSC PKCS11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
          "DNIeRemote" = "${config.programs.dnieremote.finalPackage}/lib/libdnieremotepkcs11.so";
        };
      };
      profiles.default = {
        id = 0;
      };
    };
  };
}
```

## What This Does

With this configuration:

1. AutoFirma is only available to the specified user(s)
2. Firefox integration is limited to specific Firefox profiles
3. DNIeRemote integration allows using your phone as an NFC card reader for your DNIe (see [troubleshooting](./troubleshooting.md#dnieremote-android-app-compatibility) for Android app installation)
4. The FNMT certificate configurator helps with requesting and managing digital certificates
5. Each user can have their own customized setup
6. Only users who need these tools will have them installed

## Rebuild and Apply

After adding these changes, rebuild your NixOS configuration:

```bash
sudo nixos-rebuild switch --flake .#yourHostname
```
