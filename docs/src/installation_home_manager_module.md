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

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
```

Then, configure AutoFirma for a specific user:

```nix
{
  home-manager.users.yourUsername = { config, pkgs, ... }: {
    imports = [
      autofirma-nix.homeManagerModules.default
    ];
    
    # Basic AutoFirma setup
    programs.autofirma.enable = true;
    
    # Firefox integration with specific profile(s)
    programs.autofirma.firefoxIntegration.profiles = {
      default = { # Use your actual profile name
        enable = true;
      };
    };
    
    # Optional: DNIe support via smartphone NFC
    programs.dnieremote.enable = true;
    
    # Optional: FNMT certificate configurator
    programs.configuradorfnmt.enable = true;
    programs.configuradorfnmt.firefoxIntegration.profiles = {
      default = { # Use your actual profile name
        enable = true;
      };
    };
    
    # If Firefox is managed by Home Manager
    programs.firefox = {
      enable = true;
      policies = {
        SecurityDevices = {
          # For physical smart card readers
          "OpenSC PKCS11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
          # For smartphone NFC
          "DNIeRemote" = "${config.programs.dnieremote.finalPackage}/lib/libdnieremotepkcs11.so";
        };
      };
      profiles.default = { # Use your actual profile name
        id = 0; # Makes this profile the default profile
      };
    };
  };
}
```

## What This Does

With this configuration:

1. AutoFirma is only available to the specified user(s)
2. Firefox integration is limited to specific Firefox profiles
3. Each user can have their own customized setup
4. Only users who need these tools will have them installed

## Rebuild and Apply

After adding these changes, rebuild your NixOS configuration:

```bash
sudo nixos-rebuild switch --flake .#yourHostname
```