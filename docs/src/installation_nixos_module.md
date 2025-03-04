# NixOS Module Installation

For system-wide installation where all users can access AutoFirma, DNIeRemote, and Configurador FNMT, the NixOS module is the most straightforward approach.

## Quick Start with Template

You can quickly get started with a fully configured template:

```bash
$ nix flake new --template github:nix-community/autofirma-nix#nixos-module ./my-autofirma-system
```

This creates a new directory with a complete flake configuration for NixOS with all available options.

## Minimal Configuration

For your NixOS flake configuration:

```nix
{
  nixosConfigurations.mysystem = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    
    modules = [
      autofirma-nix.nixosModules.default
      
      ({ config, pkgs, ... }: {
        # Enable AutoFirma with Firefox integration
        programs.autofirma = {
          enable = true;
          firefoxIntegration.enable = true;
        };

        # Configure Firefox
        programs.firefox = {
          enable = true;
          policies.SecurityDevices = {
            "OpenSC PKCS#11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
          };
        };
      })
    ];
  };
}
```

## What This Does

When you enable the NixOS module:

1. The `autofirma` command becomes available system-wide for signing documents
2. Firefox (if enabled through `programs.firefox.enable`) is configured to work with AutoFirma 
3. DNIeRemote integration allows using your phone as an NFC card reader for your DNIe
4. The FNMT certificate configurator helps with requesting and managing digital certificates

## Rebuild and Apply

After adding these changes, rebuild your NixOS configuration:

```bash
sudo nixos-rebuild switch --flake .#yourHostname
```