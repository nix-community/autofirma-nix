# Using your own nixpkgs (different Maven)

AutoFirma is built from three Maven fixed-output derivations (FODs): the
`jmulticard` and `clienteafirma-external` dependency repositories, and the
`clienteafirma` dependency repository. A fixed-output derivation is addressed by
the hash of its output, so the hash committed in this repository is only valid
for the Maven that produced it.

The committed hashes were computed with the Maven pinned by this flake's
`nixpkgs` input. If you follow your own nixpkgs
(`autofirma-nix.inputs.nixpkgs.follows = "nixpkgs"`) and it ships a different
Maven, the downloaded repository differs and the build fails with a hash
mismatch:

```
error: hash mismatch in fixed-output derivation '…-jmulticard-dependencies.drv':
         specified: sha256-5FxGgGvxbzto7N+/705SWyFjrQZ174DsuLxMjSbLcYs=
            got:    sha256-K63gBzsQiKMkpD27kFa6AGk/bcaIOxRxXNWLEff/Xac=
```

This page explains how to supply your own hashes so the build uses your Maven.

## What changes with the Maven version, and what does not

Only the FOD **hash** depends on the Maven version. Maven downloads its own
default lifecycle plugins (and their transitive dependencies) into the
repository, and different Maven versions ship different defaults. The resolved
**dependency versions** do not change: they are pinned through
`<dependencyManagement>` from `maven-dependency-versions.lock`, which forces the
same versions under any Maven. You reuse that lock as-is; you only recompute the
three hashes.

## Supplying your own hashes

The flake exposes `lib.mkAutofirma`, a factory that builds the package set with
your `pkgs` (and therefore your Maven) and your hashes:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    autofirma-nix = {
      url = "github:nix-community/autofirma-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, autofirma-nix }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system}.autofirma = (autofirma-nix.lib.mkAutofirma pkgs {
      maven-dependencies-hash = {
        "autofirma.clienteafirma.dependencies.jmulticard".hash = "sha256-…";
        "autofirma.clienteafirma.dependencies.clienteafirma-external".hash = "sha256-…";
        "autofirma.clienteafirma".hash = "sha256-…";
      };
    }).autofirma;
  };
}
```

Any hash you omit defaults to the committed lock, so you only need to override
the ones that mismatch. The next section explains how to obtain the values.

To use the package in a NixOS or Home Manager module, set it as
`programs.autofirma.package`:

```nix
{
  programs.autofirma = {
    enable = true;
    package = (autofirma-nix.lib.mkAutofirma pkgs {
      maven-dependencies-hash = { /* … your hashes … */ };
    }).autofirma;
  };
}
```

## Recomputing the hashes

The `update-fixed-output-derivations` script rebuilds each FOD with your Maven,
reads the hash it reports, and writes it to a lock file. It also refreshes
`maven-dependency-versions.lock` from the resolved dependency graph.

The script reads and writes two lock files in the current directory and builds
the FOD attributes of the flake in the current directory. To use it from your
own configuration, keep local copies of the lock files and have your flake read
them:

1. Copy the two lock files from this repository into your configuration. With
   the flake fetched, its store path is available via `nix flake metadata`:

   ```console
   $ src=$(nix flake metadata github:nix-community/autofirma-nix --json | jq -r .path)
   $ cp "$src/fixed-output-derivations.lock" "$src/maven-dependency-versions.lock" .
   ```

2. Point `mkAutofirma` at the local copies instead of the committed defaults:

   ```nix
   packages.${system}.autofirma = (autofirma-nix.lib.mkAutofirma pkgs {
     maven-dependencies-hash = builtins.fromJSON (builtins.readFile ./fixed-output-derivations.lock);
     maven-dependency-versions = builtins.fromJSON (builtins.readFile ./maven-dependency-versions.lock);
   }).autofirma;
   ```

3. Run the updater from your configuration directory, using this repository's
   development shell (which provides the script):

   ```console
   $ nix develop github:nix-community/autofirma-nix --command update-fixed-output-derivations
   ```

   The script clears each hash, rebuilds the FOD with your Maven, and records
   the reported hash. It prints the Maven build output as it goes. When it
   finishes, `fixed-output-derivations.lock` holds the hashes for your Maven.

4. Build as usual:

   ```console
   $ nix build .#autofirma
   ```

If you change your nixpkgs (and therefore your Maven) again, re-run the updater
to refresh the hashes.

## Notes

- The updater builds the FOD attributes directly
  (`autofirma.clienteafirma.dependencies.<name>.dependencyFod`), not the final
  package. Building the package would run its offline step against the previous
  repository and fail before the new hash is reported.
- Your flake must expose the `autofirma` package (as in the examples above) so
  the updater can resolve those attributes with `path:.#…`.
- To override Maven itself rather than follow your nixpkgs, use an overlay
  (`pkgs.extend`), not `pkgs // { maven = …; }`: `callPackage` resolves packages
  from the original package set and ignores a plain attribute-set merge.
