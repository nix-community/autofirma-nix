{
  writers,
  python3Packages,
}:
writers.writePython3Bin "pom-tools" {
  libraries = [python3Packages.lxml];
  flakeIgnore = ["E501"];
} (builtins.readFile ./pom_tools.py)
