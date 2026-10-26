# Maven picks the version of every plugin that a project does not declare from
# its own defaults, and those change between Maven releases (Maven 3.10 bumped
# most of them).  The fixed-output dependency derivations would then download a
# different set of artifacts depending on the Maven in nixpkgs, so we pin them
# to the defaults of Maven 3.9.16, which the hashes were computed with.

plugins=(
  maven-clean-plugin:3.2.0
  maven-compiler-plugin:3.15.0
  maven-dependency-plugin:3.7.0
  maven-deploy-plugin:3.1.4
  maven-install-plugin:3.1.4
  maven-jar-plugin:3.5.0
  maven-resources-plugin:3.4.0
  maven-site-plugin:3.12.1
  maven-surefire-plugin:3.5.4
)

for plugin in "${plugins[@]}"; do
  pin-managed-version plugin org.apache.maven.plugins "${plugin%%:*}" "${plugin##*:}"
done
