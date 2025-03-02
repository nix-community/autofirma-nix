{
  lib,
  writeShellApplication,
  writers,
  xmlstarlet,
  symlinkJoin,
}: let
  shellScripts = lib.mapAttrsToList (name: path:
      writeShellApplication {
        name = name;
        runtimeInputs = [ xmlstarlet ];
        text = builtins.readFile path;
      }) {
    update-java-version = ./lib/update-java-version.sh;
    update-pkg-version = ./lib/update-pkg-version.sh;
    update-dependency-version-by-groupId = ./lib/update-dependency-version-by-groupId.sh;
    remove-module-on-profile = ./lib/remove-module-on-profile.sh;
    reset-project-build-timestamp = ./lib/reset-project-build-timestamp.sh;
    reset-maven-metadata-local-timestamp = ./lib/reset-maven-metadata-local-timestamp.sh;
    update-plugin-version-by-groupId = ./lib/update-plugin-version-by-groupId.sh;
  };
  pythonScripts = lib.mapAttrsToList (name: path:
      writers.writePython3Bin name { libraries = [ ]; flakeIgnore = [ "E501" ]; } (builtins.readFile path)
      ) {
    add-xml-doclet-to-javadoc-plugin = ./lib/add-xml-doclet-to-javadoc-plugin.py;
  };
in
  symlinkJoin {
    name = "pom-tools";
    paths = shellScripts ++ pythonScripts;
  }
