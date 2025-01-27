# Installation

This project is distributed as a Nix flake for easy integration into your NixOS configuration. It provides both a NixOS module for system-wide configurations and a Home Manager module for user-specific setups. Depending on your preference, you can choose one or the other.

Keep in mind that you should enable either the NixOS module or the Home Manager module—not both simultaneously. Think of it like wearing one hat at a time.

Depending on your Nix channel:

- Use the main branch with `nixpkgs-unstable`.
- For stable channels, use the `release-XX.YY` branch corresponding to your NixOS version.

We officially support current releases. If you encounter issues on an older branch, upgrading is recommended, as it might resolve the problem—and let’s face it, newer is usually better.

Here’s an example configuration to include `autofirma-nix` as an input:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    autofirma-nix = {
      url = "github:nix-community/autofirma-nix";  # For nixpkgs-unstable
      # url = "github:nix-community/autofirma-nix/release-24.11";  # For NixOS 24.11
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

  # Further configuration details are provided in the sections below.
}
```
