{ self }:
with builtins;
let
  ascendingOrder = sort lessThan;
  truststorePath = "${self}/nix/autofirma/truststore";
  providers = fromJSON (readFile "${truststorePath}/prestadores/providers.json");
  allCAFiles = attrNames (readDir "${truststorePath}/prestadores/CAs-by-provider");
  CAFetchLinks = fromJSON (readFile "${truststorePath}/prestadores/CAs_fetch_links.json");
in
{
  testProviderListIsNotEmpty = {
    expr = length providers > 0;
    expected = true;
  };
  testCAFilesAndTrustedProvidersMatch = let
    trimJsonExt = s: substring 0 ((stringLength s) - (stringLength ".json")) s;
  in {
    expr = ascendingOrder (map trimJsonExt allCAFiles);
    expected = ascendingOrder (map (p: p.cif) providers);
  };
  testAllCAFilesHaveFetchLinkEntry = {
    expr = ascendingOrder (map (p: p.cif) CAFetchLinks);
    expected = ascendingOrder (map (p: p.cif) providers);
  };
  testAllFetchLinksHaveURLField = {
    expr = all (link: hasAttr "url" link) CAFetchLinks;
    expected = true;
  };
}
