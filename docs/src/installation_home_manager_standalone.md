# Home Manager Standalone

If you're using Home Manager in standalone mode (not integrated with NixOS configuration), this approach lets you manage AutoFirma through your personal configuration.

## Quick Start with Template

You can quickly get started with a fully configured template:

```bash
$ nix flake new --template github:nix-community/autofirma-nix#home-manager-standalone ./my-autofirma-home
```

This creates a new directory with a complete flake configuration for standalone Home Manager with all available options.

## Minimal Configuration

In your `flake.nix` for Home Manager:

```nix
{
  outputs = { self, nixpkgs, home-manager, autofirma-nix, ... }: {
    homeConfigurations."yourUsername" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      
      modules = [
        autofirma-nix.homeManagerModules.default
        
        {
          # Adds AutoFirma to your personal Home Manager setup
          programs.autofirma = {
            enable = true;
            
            # Configures Firefox integration for your specific profile(s)
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
        }
      ];
    };
  };
}
```

## What This Does

This configuration:

1. Adds AutoFirma to your personal Home Manager setup
2. Configures Firefox integration for your specific profile(s)
3. DNIeRemote integration allows using your phone as an NFC card reader for your DNIe (see [troubleshooting](./troubleshooting.md#dnieremote-android-app-compatibility) for Android app installation)
4. The FNMT certificate configurator helps with requesting and managing digital certificates
5. Provides a complete environment for working with Spanish digital signatures
6. Preserves the flexibility of Home Manager's standalone mode

## Apply the Configuration

After adding these changes, apply your Home Manager configuration:

```bash
home-manager switch --flake .#yourUsername
```
