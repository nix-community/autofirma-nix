# AutoFirma-Nix Templates

This directory contains flake templates for the three supported installation methods of autofirma-nix.

## Available Templates

1. **nixos-module** - System-wide installation for NixOS
2. **home-manager-nixos** - Per-user installation with Home Manager as a NixOS module
3. **home-manager-standalone** - Per-user installation with standalone Home Manager

Each template can be used by running:

```bash
nix flake new --template github:nix-community/autofirma-nix#template-name ./destination-directory
```

For example:

```bash
nix flake new --template github:nix-community/autofirma-nix#nixos-module ./my-autofirma-system
```