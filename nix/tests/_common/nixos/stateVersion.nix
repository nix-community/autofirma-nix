{ lib, ... }:
{
  system.stateVersion = "${lib.versions.major lib.version}.${lib.versions.minor lib.version}";
}
