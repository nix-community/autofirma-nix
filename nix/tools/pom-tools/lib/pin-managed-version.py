import glob
import sys
import xml.etree.ElementTree as ET

USAGE = """Usage: {} <plugin|dependency> <groupId> <artifactId> <version>

Adds a <pluginManagement> or <dependencyManagement> entry for the artifact to
the top-level poms under the current directory (those whose parent is not part
of the source tree), so that Maven uses <version> for it instead of what its
own defaults or a transitive version range would pick.  Modules inherit the
entry from their parent.  Poms that already manage the artifact are left alone.
"""

if len(sys.argv) != 5 or sys.argv[1] not in ("plugin", "dependency"):
    sys.stderr.write(USAGE.format(sys.argv[0]))
    sys.exit(1)

kind, group_id, artifact_id, version = sys.argv[1:]

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
        continue  # Inherits the entry from its parent

    if kind == "plugin":
        entries = child(child(child(root, "build"), "pluginManagement"), "plugins")
    else:
        entries = child(child(root, "dependencyManagement"), "dependencies")

    for entry in entries.findall("{%s}%s" % (NS, kind)):
        # A plugin without <groupId> is org.apache.maven.plugins
        entry_group = text_of(entry, "groupId") or ("org.apache.maven.plugins" if kind == "plugin" else None)
        if entry_group == group_id and text_of(entry, "artifactId") == artifact_id:
            break
    else:
        entry = ET.SubElement(entries, "{%s}%s" % (NS, kind))
        child(entry, "groupId").text = group_id
        child(entry, "artifactId").text = artifact_id
        child(entry, "version").text = version

        ET.indent(tree, space="  ")
        tree.write(pom, encoding="UTF-8", xml_declaration=True)
