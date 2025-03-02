# autofirma-nix

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
