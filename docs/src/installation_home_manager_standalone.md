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
      pkgs = nixpkgs.legacyPackages.x86_64-linux; # Adjust system if needed
      
      modules = [
        autofirma-nix.homeManagerModules.default
        
        # Your home configuration
        {
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
3. Provides a complete environment for working with Spanish digital signatures
4. Preserves the flexibility of Home Manager's standalone mode

## Apply the Configuration

After adding these changes, apply your Home Manager configuration:

```bash
home-manager switch --flake .#yourUsername
```