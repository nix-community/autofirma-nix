> **⚠️ Important Notice: Cache Configuration Update**
>
> We recently migrated the `autofirma-nix` repository from one of the creators' accounts to the Nix Community's organization.  
> As part of this migration, the binary cache has also changed. To avoid interruptions, please update your `flake.nix` configuration to use the new cache. Replace the `nixConfig` section in your `flake.nix` file with the following:
>
> ```nix
> nixConfig = {
>   extra-substituters = [
>     "https://nix-community.cachix.org"
>   ];
>   extra-trusted-public-keys = [
>     "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
>   ];
> };
> ```
>
> The old cache will be deprecated soon, so making this change promptly will ensure a seamless experience.


# autofirma-nix

[![release-24.11](https://github.com/nilp0inter/autofirma-nix/actions/workflows/build-and-cache-24-11-on-schedule.yml/badge.svg)](https://github.com/nilp0inter/autofirma-nix/actions/workflows/build-and-cache-24-11-on-schedule.yml)
[![unstable](https://github.com/nilp0inter/autofirma-nix/actions/workflows/build-and-cache-unstable-on-schedule.yml/badge.svg)](https://github.com/nilp0inter/autofirma-nix/actions/workflows/build-and-cache-unstable-on-schedule.yml)

Este repositorio contiene derivaciones de Nix, módulos de NixOS y Home Manager
para integrar AutoFirma, DNIeRemote y el Configurador FNMT en NixOS y Home
Manager.


## Ejemplo de uso
```console
$ nix run --accept-flake-config github:nilp0inter/autofirma-nix#dnieremote
```

## AutoFirma en NixOS y Home Manager

Se proporciona un módulo de NixOS para habilitar AutoFirma en NixOS y otro para
Home Manager. Sólo es necesario habilitar uno de ellos, dependiendo de si se
quiere habilitar AutoFirma a nivel de sistema o de usuario.

Una vez habilitado uno de los módulos, si se quiere utilizar AutoFirma en
Firefox, es necesario ejecutar el comando `autofirma-setup` (ver más abajo).


### Configuración de Home Manager

La integración de AutoFirma en Home Manager habilita el comando `autofirma` para
el firmado de documentos PDF y configura el navegador Firefox (si está habilitado
mediante la opción `programs.firefox.enable`) para que utilice AutoFirma en
sitios web que lo requieran.

Adicionalmente, se puede habilitar la integración con el DNIe y el DNIe por NFC
desde un móvil Android usando DNIeRemote.

`autofirma-nix` proporciona un módulo de Home Manager que debe ser importado en
el fichero de configuración de Home Manager.  Dependiendo del tipo de
instalación de Home Manager la configuración puede variar ligeramente.  A
continuación se muestran ejemplos para una configuración de tipo standalone.

```nix
# flake.nix

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    autofirma-nix = {
      url = "github:nilp0inter/autofirma-nix";  # Si estás usando NixOS unstable
      # url = "github:nilp0inter/autofirma-nix/release-24.11";  # Si estás usando NixOS 24.11
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://autofirma-nix.cachix.org"
    ];
    extra-trusted-public-keys = [
      "autofirma-nix.cachix.org-1:cDC9Dtee+HJ7QZcM8s36836scXyRToqNX/T+yvjiI0E="
    ];
  };

  outputs = {nixpkgs, home-manager, autofirma-nix, ...}: {
    homeConfigurations."miusuario" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      modules = [
        autofirma-nix.homeManagerModules.default
        ./home.nix
      ];
    };
  };
}
```

```nix
# home.nix
{ pkgs, config, ... }: {
  config = {
    programs.autofirma.enable = true;
    programs.autofirma.firefoxIntegration.profiles = {
      miperfil = {  # El nombre del perfil de firefox donde se habilitará AutoFirma
        enable = true;
      };
    };
    programs.dnieremote.enable = true;

    programs.configuradorfnmt.enable = true;
    programs.configuradorfnmt.firefoxIntegration.profiles = {
      miperfil = {  # El nombre del perfil de firefox donde se habilitará el Configurador FNMT
        enable = true;
      };
    };

    programs.firefox = {
      enable = true;
      policies = {
        SecurityDevices = {
          "OpenSC PKCS11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";  # Para poder utilizar el DNIe, y otras tarjetas inteligentes
          "DNIeRemote" = "${config.programs.dnieremote.finalPackage}/lib/libdnieremotepkcs11.so";  # Para poder utilizar el DNIe por NFC desde un móvil Android
        };
      };
      profiles.miperfil = {
        id = 0;  # Hace que este perfil sea el perfil por defecto
        # ... El resto de opciones de configuración de este perfil
      };
    };
  };
}
```

### Configuración de NixOS

La integración de AutoFirma en NixOS habilita el comando `autofirma` para el
firmado de documentos PDF y configura el navegador Firefox (si está habilitado
mediante la opción `programs.firefox.enable`) para que utilice AutoFirma en
sitios web que lo requieran.

Adicionalmente, se puede habilitar la integración con el DNIe y el DNIe por NFC
desde un móvil Android usando DNIeRemote.


```nix
# flake.nix

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    autofirma-nix.url = "github:nilp0inter/autofirma-nix";
    # autofirma-nix.url = "github:nilp0inter/autofirma-nix/release-24.11";  # Si estás usando NixOS 24.11
  };

  outputs = { self, nixpkgs, autofirma-nix, ... }: {
    nixosConfigurations."hostname" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        autofirma-nix.nixosModules.default
        ({ pkgs, config, ... }: {
          programs.autofirma.enable = true;
          programs.autofirma.fixJavaCerts = true;
          programs.autofirma.firefoxIntegration.enable = true;  # Para que Firefox utilice AutoFirma

          programs.dnieremote.enable = true;

          programs.configuradorfnmt.enable = true;
          programs.configuradorfnmt.firefoxIntegration.enable = true;  # Para que Firefox utilice el Configurador FNMT

          # Firefox
          programs.firefox.enable = true;
          programs.firefox.policies =  {
            SecurityDevices = {
              "OpenSC PKCS#11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";  # Para poder utilizar el DNIe, y otras tarjetas inteligentes
              "DNIeRemote" = "${config.programs.dnieremote.finalPackage}/lib/libdnieremotepkcs11.so";  # Para poder utilizar el DNIe por NFC desde un móvil Android
            };
          };
        })
      ];
    };
  };
}
```

### Creación de certificados

Una vez instalado y habilitado AutoFirma, es necesario crear un certificado
para que el navegador pueda comunicarse con AutoFirma. Para ello, se debe ejecutar
el siguiente comando (con Firefox abierto):

```
$ autofirma-setup
```

Después es necesario reiniciar Firefox para que los cambios surtan efecto.

### Desinstalación de certificados

Si se desea desinstalar los certificados creados por `autofirma-setup`, se puede
ejecutar el siguiente comando:

```
$ autofirma-setup --uninstall
```

## Solución de problemas

### Los dispositivos de seguridad no parecen actualizarse

Si se ha instalado AutoFirma y se ha habilitado la integración con Firefox, pero
Firefox no detecta los dispositivos de seguridad, es posible que sea necesario
eliminar el fichero `pkcs11.txt` de la carpeta de perfil de Firefox. Por ejemplo,
si se activa el módulo de Home Manager y su perfil se llama `miperfil`, el fichero
se encontrará en `~/.mozilla/firefox/miperfil/pkcs11.txt`.

Bastará con eliminarlo y reiniciar Firefox.

```console
$ rm ~/.mozilla/firefox/miperfil/pkcs11.txt
$ firefox
```
