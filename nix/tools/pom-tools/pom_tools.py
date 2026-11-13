"""Single-pass Maven POM patcher driven by a JSON rules file.

The rules file is generated from Nix (``writers.writeJSON``) and describes, as a
JSON object, the operations to apply to every ``pom.xml`` under the working
directory.  Top-level keys are executed in a fixed order, independent of the
order they appear in the JSON, because Nix and ``jq`` do not preserve attribute
set key order.

Operations:

    javaVersion            str    Set compiler <source>/<target> in plugins.
    pkgVersion             str    Set <project><version> and <parent><version>.
    dependencyVersions     map    groupId -> version for declared <dependency>.
    removeProfileModules   map    profile id -> [module] to delete.
    resetBuildTimestamp    bool   Set project.build.outputTimestamp property.
    pinDependencyVersions  map    "groupId:artifactId" -> version, pinned into
                                  <dependencyManagement> of top-level poms.
    pluginVersions         list   [{groupId, artifactId, version}] to update.
    addXmlDoclet           map    {javadocVersion, xmlDocletVersion} registered
                                  on the root pom's maven-javadoc-plugin.
    resetMetadataTimestamp bool   Reset maven-metadata-local.xml lastUpdated.

The first eight operate on ``pom.xml`` files; ``resetMetadataTimestamp`` operates
on ``maven-metadata-local.xml`` files and is used in a separate fixup pass.

All poms are parsed once, mutated in memory, and only modified trees are written
back.  Running the same rules twice produces no further writes (idempotent).
"""

import json
import sys
from pathlib import Path

from lxml import etree
from lxml.builder import ElementMaker

POM_NS = "http://maven.apache.org/POM/4.0.0"
NS = {"m": POM_NS}
E = ElementMaker(namespace=POM_NS, nsmap={None: POM_NS})
BUILD_TIMESTAMP = "1980-01-01T00:00:02Z"
METADATA_TIMESTAMP = "19800101000002"


# Canonical execution order.  Nix serializes attribute sets alphabetically, so
# the runner must not rely on the JSON key order.  Management pins run before
# plugin version updates, and the doclet registration runs last.
OPERATION_ORDER = (
    "javaVersion",
    "pkgVersion",
    "dependencyVersions",
    "removeProfileModules",
    "resetBuildTimestamp",
    "pinDependencyVersions",
    "pluginVersions",
    "addXmlDoclet",
    "resetMetadataTimestamp",
)


class RulesError(ValueError):
    """Raised when the rules file is malformed."""


def _require_str(value, name):
    if not isinstance(value, str) or not value:
        raise RulesError(f"{name} must be a non-empty string")
    return value


def _require_map(value, name):
    if not isinstance(value, dict):
        raise RulesError(f"{name} must be an object")
    return value


def _require_bool(value, name):
    if not isinstance(value, bool):
        raise RulesError(f"{name} must be a boolean")
    return value


def _validate_plugin_entry(entry, name):
    if not isinstance(entry, dict):
        raise RulesError(f"{name} entries must be objects")
    for field in ("groupId", "artifactId", "version"):
        _require_str(entry.get(field), f"{name}.{field}")
    return entry


def validate_rules(rules):
    """Check the rules object, returning it unchanged or raising RulesError."""
    if not isinstance(rules, dict):
        raise RulesError("rules must be a JSON object")
    unknown = set(rules) - set(OPERATION_ORDER)
    if unknown:
        raise RulesError(f"unknown operations: {sorted(unknown)}")

    if "javaVersion" in rules:
        _require_str(rules["javaVersion"], "javaVersion")
    if "pkgVersion" in rules:
        _require_str(rules["pkgVersion"], "pkgVersion")
    if "dependencyVersions" in rules:
        for group, version in _require_map(
            rules["dependencyVersions"], "dependencyVersions"
        ).items():
            _require_str(group, "dependencyVersions key")
            _require_str(version, f"dependencyVersions[{group}]")
    if "removeProfileModules" in rules:
        for profile, modules in _require_map(
            rules["removeProfileModules"], "removeProfileModules"
        ).items():
            _require_str(profile, "removeProfileModules key")
            if not isinstance(modules, list):
                raise RulesError(f"removeProfileModules[{profile}] must be a list")
            for module in modules:
                _require_str(module, f"removeProfileModules[{profile}] entry")
    for flag in ("resetBuildTimestamp", "resetMetadataTimestamp"):
        if flag in rules:
            _require_bool(rules[flag], flag)
    if "pinDependencyVersions" in rules:
        for coord, version in _require_map(
            rules["pinDependencyVersions"], "pinDependencyVersions"
        ).items():
            _require_str(version, f"pinDependencyVersions[{coord}]")
            if coord.count(":") != 1:
                raise RulesError(
                    f"pinDependencyVersions key {coord!r} must be groupId:artifactId"
                )
    if "pluginVersions" in rules:
        entries = rules["pluginVersions"]
        if not isinstance(entries, list):
            raise RulesError("pluginVersions must be a list")
        for i, entry in enumerate(entries):
            _validate_plugin_entry(entry, f"pluginVersions[{i}]")
    if "addXmlDoclet" in rules:
        doclet = _require_map(rules["addXmlDoclet"], "addXmlDoclet")
        _require_str(doclet.get("javadocVersion"), "addXmlDoclet.javadocVersion")
        _require_str(doclet.get("xmlDocletVersion"), "addXmlDoclet.xmlDocletVersion")
    return rules


def _text(element):
    return (element.text or "").strip() if element is not None else None


def _find(element, path):
    found = element.xpath(path, namespaces=NS)
    return found[0] if found else None


def _child(parent, tag):
    """Return the direct child <tag> of parent, creating it if needed."""
    found = _find(parent, f"m:{tag}")
    if found is None:
        found = etree.SubElement(parent, f"{{{POM_NS}}}{tag}")
    return found


class PomWorkspace:
    """Every pom.xml under a root, parsed once and written back only if changed.

    Trees are stored in their original (unreformatted) form.  Before writing,
    the current tree is compared against a parse of the file on disk; only
    trees that differ are re-indented and written.  This keeps untouched files
    byte-identical and makes a second run with the same rules a no-op.
    """

    def __init__(self, root):
        self.root = Path(root)
        self._parser = etree.XMLParser(remove_blank_text=True)
        self.trees = {
            path: etree.parse(str(path), self._parser)
            for path in sorted(self.root.rglob("pom.xml"))
            if path.is_file()
        }

    def __iter__(self):
        return iter(self.trees.values())

    def items(self):
        return self.trees.items()

    def values(self):
        return self.trees.values()

    def root_pom(self):
        path = self.root / "pom.xml"
        if path not in self.trees:
            raise RulesError("addXmlDoclet requires a root pom.xml")
        return self.trees[path]

    def local_coordinates(self):
        """The (groupId, artifactId) pairs declared anywhere in the tree."""
        coords = set()
        for tree in self.trees.values():
            project = tree.getroot()
            group = _text(_find(project, "m:groupId")) or _text(
                _find(project, "m:parent/m:groupId")
            )
            artifact = _text(_find(project, "m:artifactId"))
            coords.add((group, artifact))
        return coords

    def top_level(self):
        """Poms whose <parent> is not part of the source tree.

        Modules inherit management entries from their parent, so only top-level
        poms need them.
        """
        coords = self.local_coordinates()
        result = []
        for path, tree in self.trees.items():
            project = tree.getroot()
            parent = _find(project, "m:parent")
            if parent is not None:
                pair = (
                    _text(_find(parent, "m:groupId")),
                    _text(_find(parent, "m:artifactId")),
                )
                if pair in coords:
                    continue
            result.append((path, tree))
        return result

    def write_dirty(self):
        """Write only the trees whose content differs from disk."""
        for path, tree in self.trees.items():
            on_disk = etree.parse(str(path), self._parser)
            if _serialize(tree) != _serialize(on_disk):
                etree.indent(tree, space="  ")
                tree.write(str(path), encoding="UTF-8", xml_declaration=True)


def _serialize(tree):
    return etree.tostring(tree)


def update_java_version(poms, version):
    for tree in poms:
        nodes = tree.xpath(
            "//m:plugin/m:configuration/*[self::m:source or self::m:target]",
            namespaces=NS,
        )
        for node in nodes:
            node.text = version


def update_pkg_version(poms, version):
    for tree in poms:
        project = tree.getroot()
        for path in ("m:version", "m:parent/m:version"):
            node = _find(project, path)
            if node is not None:
                node.text = version


def update_dependency_versions(poms, versions):
    for group, version in versions.items():
        for tree in poms:
            nodes = tree.xpath(
                "//m:dependencies/m:dependency[m:groupId=$g]/m:version",
                namespaces=NS,
                g=group,
            )
            for node in nodes:
                node.text = version


def remove_profile_modules(poms, removals):
    for profile_id, modules in removals.items():
        for tree in poms:
            for module in modules:
                nodes = tree.xpath(
                    "/m:project/m:profiles/m:profile[m:id=$p]"
                    "/m:modules/m:module[text()=$m]",
                    namespaces=NS,
                    p=profile_id,
                    m=module,
                )
                for node in nodes:
                    node.getparent().remove(node)


def reset_build_timestamp(poms):
    for tree in poms:
        properties = _child(tree.getroot(), "properties")
        node = _find(properties, "m:project.build.outputTimestamp")
        if node is None:
            node = etree.SubElement(
                properties, f"{{{POM_NS}}}project.build.outputTimestamp"
            )
        node.text = BUILD_TIMESTAMP


def _dependency_management_entries(poms):
    """The <dependencyManagement><dependencies> container of each top-level pom.

    Modules inherit management entries from their parent, so only top-level poms
    need them.
    """
    containers = {}
    for path, tree in poms.top_level():
        project = tree.getroot()
        containers[path] = _child(
            _child(project, "dependencyManagement"), "dependencies"
        )
    return containers


def _existing_managed(entries):
    managed = set()
    for entry in entries.findall(f"{{{POM_NS}}}dependency"):
        group = _text(_find(entry, "m:groupId"))
        managed.add((group, _text(_find(entry, "m:artifactId"))))
    return managed


def pin_dependency_versions(poms, versions):
    if not versions:
        return
    containers = _dependency_management_entries(poms)
    for entries in containers.values():
        managed = _existing_managed(entries)
        for coord, version in sorted(versions.items()):
            group, artifact = coord.split(":")
            if (group, artifact) in managed:
                continue
            entries.append(
                E.dependency(
                    E.groupId(group), E.artifactId(artifact), E.version(version)
                )
            )


def update_plugin_versions(poms, entries):
    for entry in entries:
        group, artifact, version = (
            entry["groupId"],
            entry["artifactId"],
            entry["version"],
        )
        for tree in poms:
            nodes = tree.xpath(
                "//m:build//m:plugin[m:groupId=$g and m:artifactId=$a]/m:version",
                namespaces=NS,
                g=group,
                a=artifact,
            )
            for node in nodes:
                node.text = version


def add_xml_doclet(root_pom, javadoc_version, xml_doclet_version):
    """Register the xmldoclet execution on the root pom's javadoc plugin.

    Replaces any existing maven-javadoc-plugin declaration under build/plugins.
    """
    project = root_pom.getroot()
    plugins = _child(_child(project, "build"), "plugins")
    for plugin in plugins.findall(f"{{{POM_NS}}}plugin"):
        if _text(_find(plugin, "m:artifactId")) == "maven-javadoc-plugin":
            plugins.remove(plugin)
    plugin = E.plugin(
        E.groupId("org.apache.maven.plugins"),
        E.artifactId("maven-javadoc-plugin"),
        E.version(javadoc_version),
        E.executions(
            E.execution(
                E.id("xml-doclet"),
                E.phase("prepare-package"),
                E.goals(E.goal("javadoc")),
                E.configuration(
                    E.useStandardDocletOptions("false"),
                    E.doclet("com.manticore.tools.xmldoclet.XmlDoclet"),
                    E.additionalOptions("-d ${project.build.directory}"),
                    E.docletArtifact(
                        E.groupId("com.manticore-projects.tools"),
                        E.artifactId("xml-doclet"),
                        E.version(xml_doclet_version),
                        E.classifier("all"),
                    ),
                ),
            )
        ),
    )
    plugins.append(plugin)


def reset_metadata_timestamp(root):
    for path in sorted(Path(root).rglob("maven-metadata-local.xml")):
        if not path.is_file():
            continue
        tree = etree.parse(str(path))
        for node in tree.xpath("/metadata/versioning/lastUpdated"):
            node.text = METADATA_TIMESTAMP
        etree.indent(tree, space="  ")
        tree.write(str(path), encoding="UTF-8", xml_declaration=True)


def apply_pom_rules(poms, rules):
    """Apply all pom operations in canonical order, in memory."""
    if "javaVersion" in rules:
        update_java_version(poms, rules["javaVersion"])
    if "pkgVersion" in rules:
        update_pkg_version(poms, rules["pkgVersion"])
    if "dependencyVersions" in rules:
        update_dependency_versions(poms, rules["dependencyVersions"])
    if "removeProfileModules" in rules:
        remove_profile_modules(poms, rules["removeProfileModules"])
    if rules.get("resetBuildTimestamp"):
        reset_build_timestamp(poms)
    if "pinDependencyVersions" in rules:
        pin_dependency_versions(poms, rules["pinDependencyVersions"])
    if "pluginVersions" in rules:
        update_plugin_versions(poms, rules["pluginVersions"])
    if "addXmlDoclet" in rules:
        doclet = rules["addXmlDoclet"]
        add_xml_doclet(
            poms.root_pom(), doclet["javadocVersion"], doclet["xmlDocletVersion"]
        )


def apply_rules(root, rules):
    """Load, mutate and write poms; handle the metadata pass separately."""
    validate_rules(rules)
    poms = PomWorkspace(root)
    apply_pom_rules(poms, rules)
    poms.write_dirty()
    if rules.get("resetMetadataTimestamp"):
        reset_metadata_timestamp(root)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 1:
        sys.stderr.write(f"Usage: {sys.argv[0]} <pom-rules.json>\n")
        return 1
    rules_path = Path(argv[0])
    try:
        rules = json.loads(rules_path.read_text(encoding="utf-8"))
        apply_rules(Path.cwd(), rules)
    except RulesError as exc:
        sys.stderr.write(f"pom-tools: {exc}\n")
        return 1
    except (OSError, etree.XMLSyntaxError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"pom-tools: {exc}\n")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
