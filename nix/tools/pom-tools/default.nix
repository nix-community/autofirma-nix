{
  writers,
  python3Packages,
}:
writers.writePython3Bin "pom-apply-rules" {
  libraries = [python3Packages.lxml];
  flakeIgnore = ["E501"];
} (builtins.readFile ./pom_apply_rules.py)
