shopt -s globstar

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <groupId> <artifactId> <new_version>"
    exit 1
fi

GROUP_ID="$1"
ARTIFACT_ID="$2"
NEW_VERSION="$3"

xmlstarlet ed --inplace -N mvn=http://maven.apache.org/POM/4.0.0 \
    --update "/mvn:project//mvn:build//mvn:plugin[mvn:groupId='$GROUP_ID' and mvn:artifactId='$ARTIFACT_ID']/mvn:version" \
    --value "$NEW_VERSION" \
    pom.xml ./**/pom.xml
