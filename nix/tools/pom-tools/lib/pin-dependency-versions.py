import glob
import json
import sys
import xml.etree.ElementTree as ET

USAGE = """Usage: {} <lock-file> <key>

Pins the Maven dependencies of the project under the current directory to the
exact versions recorded in <lock-file> under <key>.  The lock maps
"groupId:artifactId" coordinates to the versions captured by
update-fixed-output-derivations from a real Maven resolution.

Adds a <dependencyManagement> entry to every top-level pom (those whose parent
is not part of the source tree); modules inherit the entries from their parent.
This replaces the versions Maven would otherwise resolve from transitive version
ranges against Maven Central's mutable metadata.  Poms that already manage an
artifact are left alone.  A missing key or empty version set is a no-op, so the
first (uncaptured) build still succeeds.
"""

if len(sys.argv) != 3:
    sys.stderr.write(USAGE.format(sys.argv[0]))
    sys.exit(1)

lock_file, key = sys.argv[1:]

with open(lock_file) as f:
    lock = json.load(f)

versions = lock.get(key, {}).get("versions", {})
if not versions:
    sys.exit(0)

NS = "http://maven.apache.org/POM/4.0.0"
ET.register_namespace("", NS)


def find(element, path):
    return element.find("/".join("{%s}%s" % (NS, tag) for tag in path.split("/")))


def text_of(element, path):
    found = None if element is None else find(element, path)
    return None if found is None else (found.text or "").strip()


def child(parent, tag):
    """Return the direct child <tag> of parent, creating it if needed."""
    found = find(parent, tag)
    if found is None:
        found = ET.SubElement(parent, "{%s}%s" % (NS, tag))
    return found


def parse(pom):
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    return ET.parse(pom, parser)


poms = {pom: parse(pom) for pom in glob.glob("**/pom.xml", recursive=True)}

coordinates = set()
for tree in poms.values():
    root = tree.getroot()
    coordinates.add((text_of(root, "groupId") or text_of(root, "parent/groupId"), text_of(root, "artifactId")))

for pom, tree in poms.items():
    root = tree.getroot()
    parent = find(root, "parent")
    if parent is not None and (text_of(parent, "groupId"), text_of(parent, "artifactId")) in coordinates:
        continue  # Inherits the entries from its parent

    entries = child(child(root, "dependencyManagement"), "dependencies")

    managed = set()
    for entry in entries.findall("{%s}dependency" % NS):
        managed.add((text_of(entry, "groupId"), text_of(entry, "artifactId")))

    changed = False
    for coordinate, version in sorted(versions.items()):
        group_id, artifact_id = coordinate.split(":")
        if (group_id, artifact_id) in managed:
            continue
        entry = ET.SubElement(entries, "{%s}dependency" % NS)
        child(entry, "groupId").text = group_id
        child(entry, "artifactId").text = artifact_id
        child(entry, "version").text = version
        changed = True

    if changed:
        ET.indent(tree, space="  ")
        tree.write(pom, encoding="UTF-8", xml_declaration=True)
