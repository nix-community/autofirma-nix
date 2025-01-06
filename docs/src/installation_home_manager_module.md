# Home Manager module

If you prefer per-user flexibility and customization, the **autofirma-nix** Home Manager module is the way to go. Here’s how you can set it up in your Home Manager configuration:

```nix
{
  outputs = { self, home-manager, autofirma-nix, nixpkgs, ... }:
    {
      homeConfigurations."my-user" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;

        modules = [
          autofirma-nix.homeManagerModules.default

          {
            programs.autofirma.enable = true;
            programs.autofirma.firefoxIntegration.profiles = {
              myprofile = {
                enable = true;
              };
            };

            programs.dnieremote.enable = true;

            programs.configuradorfnmt.enable = true;
            programs.configuradorfnmt.firefoxIntegration.profiles = {
              myprofile = {
                enable = true;
              };
            };

            programs.firefox = {
              enable = true;
              policies = {
                SecurityDevices = {
                  "OpenSC PKCS11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
                  "DNIeRemote" = "${config.programs.dnieremote.finalPackage}/lib/libdnieremotepkcs11.so";
                };
              };
              profiles.myprofile = {
                id = 0;
              };
            };
          }
        ];
      };
    };
}
```
