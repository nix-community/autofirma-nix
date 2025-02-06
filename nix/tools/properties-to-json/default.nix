{ writers }:
writers.writePython3Bin "properties-to-json" { } (builtins.readFile ./properties-to-json.py)
