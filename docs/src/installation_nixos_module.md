# NixOS module

For those who prefer system-wide configurations, **autofirma-nix** offers a dedicated NixOS module. Below is an example of how to configure the NixOS module. (The `inputs` section is covered in the previous section.)

```nix
{
  outputs = { self, nixpkgs, autofirma-nix, ... }:
    {
      nixosConfigurations.myHostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          autofirma-nix.nixosModules.default

          {
            programs.autofirma.enable = true;
            programs.autofirma.firefoxIntegration.enable = true;

            programs.dnieremote.enable = true;

            programs.configuradorfnmt.enable = true;
            programs.configuradorfnmt.firefoxIntegration.enable = true;

            programs.firefox.enable = true;
            programs.firefox.policies = {
              SecurityDevices = {
                "OpenSC PKCS#11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
                "DNIeRemote"     = "${config.programs.dnieremote.finalPackage}/lib/libdnieremotepkcs11.so";
              };
            };
          }
        ];
      };
    };
}
```
