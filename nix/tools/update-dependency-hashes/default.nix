{ writers, python3Packages }:
writers.writePython3Bin "update-dependency-hashes" { 
  libraries = [ python3Packages.toposort ];
  flakeIgnore = [ "E501" ];
} (builtins.readFile ./update-dependency-hashes.py)
