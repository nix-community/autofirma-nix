{ writers, python3Packages }:
writers.writePython3Bin "update-fixed-output-derivations" { 
  libraries = [ python3Packages.toposort ];
  flakeIgnore = [ "E501" ];
} (builtins.readFile ./update-fixed-output-derivations.py)
