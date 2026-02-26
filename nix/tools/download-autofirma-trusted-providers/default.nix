{
  writeShellApplication,
  xmlstarlet,
  jq,
}:
writeShellApplication {
  name = "download-autofirma-trusted-providers";
  runtimeInputs = [xmlstarlet jq];
  text = builtins.readFile ./download-autofirma-trusted-providers.sh;
  bashOptions = [
    "errexit"
    "nounset"
    "pipefail"
    "xtrace"
  ];
}
