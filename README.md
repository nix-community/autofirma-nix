<p align="center">
  <a href="https://github.com/nix-community/autofirma-nix">
    <picture>
      <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/nix-community/autofirma-nix/main/artwork/logo.svg">
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/nix-community/autofirma-nix/main/artwork/logo_white.svg">
      <img src="https://raw.githubusercontent.com/nix-community/autofirma-nix/main/artwork/logo.svg" width="200px" alt="Autofirma-Nix Logo">
    </picture>
  </a>
</p>

<h1 align="center">autofirma-nix</h1>

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)

Nix packages, NixOS modules, and Home Manager modules for the suite of tools required to interact with Spain's public administration digital services:

- **AutoFirma** - Digital document signing and web authentication
- **DNIeRemote** - Use your smartphone as an NFC reader for your Spanish national ID card
- **Configurador FNMT-RCM** - Request and install certificates from the Spanish Royal Mint

## Quick Start

```bash
# Run DNIeRemote directly
nix run github:nix-community/autofirma-nix#dnieremote

# Create a new NixOS configuration with AutoFirma
nix flake new --template github:nix-community/autofirma-nix#nixos-module ./my-autofirma-system

# Create a new Home Manager configuration with AutoFirma
nix flake new --template github:nix-community/autofirma-nix#home-manager-standalone ./my-autofirma-home
```

## Documentation

Comprehensive documentation is available at:
https://nix-community.github.io/autofirma-nix/

There you'll find:
- Detailed installation instructions for NixOS and Home Manager
- Configuration options reference
- Security considerations
- Troubleshooting guide

## License

This project is licensed under the MIT License - see the LICENSE file for details.
