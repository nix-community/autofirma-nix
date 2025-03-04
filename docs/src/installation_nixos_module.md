# NixOS Module Installation

For system-wide installation where all users can access AutoFirma, DNIeRemote, and Configurador FNMT, the NixOS module is the most straightforward approach.

## Quick Start with Template

You can quickly get started with a fully configured template:

```bash
$ nix flake new --template github:nix-community/autofirma-nix#nixos-module ./my-autofirma-system
```

This creates a new directory with a complete flake configuration for NixOS with all available options.

## Minimal Configuration

Add the following to your NixOS configuration:

```nix
{
  imports = [
    # ... your other imports
    autofirma-nix.nixosModules.default
  ];

  # Basic AutoFirma setup
  programs.autofirma = {
    enable = true;
    # Enable Firefox integration to use AutoFirma with web applications
    firefoxIntegration.enable = true;
  };

  # Optional: Enable DNIe support via NFC with mobile phone
  programs.dnieremote.enable = true;

  # Optional: Enable FNMT certificate configurator
  programs.configuradorfnmt = {
    enable = true;
    firefoxIntegration.enable = true;
  };

  # If Firefox is managed by NixOS, configure security devices
  programs.firefox = {
    enable = true;
    policies = {
      SecurityDevices = {
        # For standard smart card readers (physical DNIe)
        "OpenSC PKCS#11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
        # For DNIe via NFC from smartphone
        "DNIeRemote" = "${config.programs.dnieremote.finalPackage}/lib/libdnieremotepkcs11.so";
      };
    };
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