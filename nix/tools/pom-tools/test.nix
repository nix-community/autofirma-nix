{
  runCommand,
  python3,
}: let
  python = python3.withPackages (ps: [ps.lxml ps.pytest]);
in
  runCommand "pom-tools-tests" {
    nativeBuildInputs = [python];
    src = ./.;
  } ''
    cp -r $src ./pom-tools
    chmod -R u+w ./pom-tools
    cd ./pom-tools
    python -m pytest test_pom_tools.py -q
    touch $out
  ''
