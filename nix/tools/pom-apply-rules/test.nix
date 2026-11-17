{
  runCommand,
  python3,
}: let
  python = python3.withPackages (ps: [ps.lxml ps.pytest]);
in
  runCommand "pom-apply-rules-tests" {
    nativeBuildInputs = [python];
    src = ./.;
  } ''
    cp -r $src ./pom-apply-rules
    chmod -R u+w ./pom-apply-rules
    cd ./pom-apply-rules
    python -m pytest test_pom_apply_rules.py -q
    touch $out
  ''
