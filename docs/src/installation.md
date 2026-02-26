# Installation

This project is distributed as a Nix flake that supports three integration paths:

1. **NixOS module** - For system-wide installation
2. **Home Manager module with NixOS** - For per-user installation when Home Manager is used as a NixOS module
3. **Home Manager standalone** - For per-user installation with standalone Home Manager

## Flake Input Setup

For all installation methods, you'll need to add autofirma-nix to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Only needed for Home Manager options
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    autofirma-nix = {
      url = "github:nix-community/autofirma-nix";  # For nixpkgs-unstable
      # url = "github:nix-community/autofirma-nix/release-25.05";  # For NixOS 25.05
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
```

The binary cache configuration is strongly recommended to avoid unnecessary local compilation.
