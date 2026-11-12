"""Tests for the single-pass pom-tools patcher.

Each operation is exercised against realistic Maven POM fixtures, plus the
cross-cutting invariants: idempotency, dirty-only writes, canonical operation
ordering, and top-level pom detection.
"""

import json

import pytest
from lxml import etree

import pom_tools as pt

NS = {"m": pt.POM_NS}


def pom(body, group="com.example", artifact="root", version="1.0.0", parent=None):
    """Build a minimal POM string with the Maven namespace."""
    parent_xml = ""
    if parent is not None:
        pg, pa, pv = parent
        parent_xml = (
            f"<parent><groupId>{pg}</groupId><artifactId>{pa}</artifactId>"
            f"<version>{pv}</version></parent>"
        )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<project xmlns="{pt.POM_NS}">'
        f"{parent_xml}"
        f"<groupId>{group}</groupId>"
        f"<artifactId>{artifact}</artifactId>"
        f"<version>{version}</version>"
        f"{body}"
        "</project>"
    )


def write_pom(root, rel, text):
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def parse(path):
    return etree.parse(str(path), etree.XMLParser(remove_blank_text=True))


def texts(tree, xpath):
    return [n.text for n in tree.xpath(xpath, namespaces=NS)]


def run(root, rules):
    pt.apply_rules(root, rules)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------


class TestValidation:
    def test_accepts_empty_object(self):
        assert pt.validate_rules({}) == {}

    def test_accepts_full_rules(self):
        rules = {
            "javaVersion": "17",
            "pkgVersion": "1.2.3",
            "dependencyVersions": {"g": "1"},
            "removeProfileModules": {"p": ["m"]},
            "resetBuildTimestamp": True,
            "pinDependencyVersions": {"g:a": "1"},
            "pluginVersions": [{"groupId": "g", "artifactId": "a", "version": "1"}],
            "addXmlDoclet": {"javadocVersion": "3", "xmlDocletVersion": "2"},
            "resetMetadataTimestamp": True,
        }
        assert pt.validate_rules(rules) is rules

    def test_rejects_non_object(self):
        with pytest.raises(pt.RulesError):
            pt.validate_rules([])

    def test_rejects_unknown_operation(self):
        with pytest.raises(pt.RulesError, match="unknown operations"):
            pt.validate_rules({"bogus": 1})

    @pytest.mark.parametrize(
        "rules",
        [
            {"javaVersion": ""},
            {"javaVersion": 17},
            {"pkgVersion": None},
            {"dependencyVersions": {"g": ""}},
            {"dependencyVersions": "not-a-map"},
            {"removeProfileModules": {"p": "not-a-list"}},
            {"removeProfileModules": {"p": [""]}},
            {"resetBuildTimestamp": "yes"},
            {"pinDependencyVersions": {"no-colon": "1"}},
            {"pinDependencyVersions": {"a:b:c": "1"}},
            {"pinDependencyVersions": {"g:a": ""}},
            {"pluginVersions": "not-a-list"},
            {"pluginVersions": [{"groupId": "g"}]},
            {"pluginVersions": [{"groupId": "g", "artifactId": "a", "version": ""}]},
            {"addXmlDoclet": {"javadocVersion": "3"}},
            {"addXmlDoclet": {"xmlDocletVersion": "2"}},
        ],
    )
    def test_rejects_malformed(self, rules):
        with pytest.raises(pt.RulesError):
            pt.validate_rules(rules)


# ---------------------------------------------------------------------------
# javaVersion
# ---------------------------------------------------------------------------


class TestJavaVersion:
    def test_updates_source_and_target(self, tmp_path):
        body = (
            "<build><plugins><plugin>"
            "<artifactId>maven-compiler-plugin</artifactId>"
            "<configuration><source>1.8</source><target>1.8</target>"
            "<release>8</release></configuration>"
            "</plugin></plugins></build>"
        )
        path = write_pom(tmp_path, "pom.xml", pom(body))
        run(tmp_path, {"javaVersion": "17"})
        tree = parse(path)
        assert texts(tree, "//m:configuration/m:source") == ["17"]
        assert texts(tree, "//m:configuration/m:target") == ["17"]
        # release is not source/target and must be left alone.
        assert texts(tree, "//m:configuration/m:release") == ["8"]

    def test_updates_nested_plugin_management(self, tmp_path):
        body = (
            "<build><pluginManagement><plugins><plugin>"
            "<configuration><source>1.8</source></configuration>"
            "</plugin></plugins></pluginManagement></build>"
        )
        path = write_pom(tmp_path, "pom.xml", pom(body))
        run(tmp_path, {"javaVersion": "11"})
        assert texts(parse(path), "//m:configuration/m:source") == ["11"]

    def test_no_config_is_noop(self, tmp_path):
        path = write_pom(tmp_path, "pom.xml", pom(""))
        before = path.read_bytes()
        run(tmp_path, {"javaVersion": "17"})
        assert path.read_bytes() == before


# ---------------------------------------------------------------------------
# pkgVersion
# ---------------------------------------------------------------------------


class TestPkgVersion:
    def test_updates_project_and_parent_version(self, tmp_path):
        path = write_pom(
            tmp_path,
            "sub/pom.xml",
            pom("", artifact="child", parent=("com.example", "root", "1.0.0")),
        )
        write_pom(tmp_path, "pom.xml", pom(""))
        run(tmp_path, {"pkgVersion": "9.9.9"})
        tree = parse(path)
        assert texts(tree, "/m:project/m:version") == ["9.9.9"]
        assert texts(tree, "/m:project/m:parent/m:version") == ["9.9.9"]
        # Identity is untouched.
        assert texts(tree, "/m:project/m:artifactId") == ["child"]
        assert texts(tree, "/m:project/m:parent/m:artifactId") == ["root"]

    def test_root_without_parent(self, tmp_path):
        path = write_pom(tmp_path, "pom.xml", pom(""))
        run(tmp_path, {"pkgVersion": "2.0"})
        tree = parse(path)
        assert texts(tree, "/m:project/m:version") == ["2.0"]
        assert tree.xpath("/m:project/m:parent", namespaces=NS) == []


# ---------------------------------------------------------------------------
# dependencyVersions
# ---------------------------------------------------------------------------


class TestDependencyVersions:
    def test_updates_matching_group_only(self, tmp_path):
        body = (
            "<dependencies>"
            "<dependency><groupId>org.foo</groupId><artifactId>a</artifactId>"
            "<version>1.0</version></dependency>"
            "<dependency><groupId>org.bar</groupId><artifactId>b</artifactId>"
            "<version>2.0</version></dependency>"
            "</dependencies>"
        )
        path = write_pom(tmp_path, "pom.xml", pom(body))
        run(tmp_path, {"dependencyVersions": {"org.foo": "1.9"}})
        tree = parse(path)
        assert texts(tree, "//m:dependency[m:groupId='org.foo']/m:version") == ["1.9"]
        assert texts(tree, "//m:dependency[m:groupId='org.bar']/m:version") == ["2.0"]

    def test_updates_dependency_management_too(self, tmp_path):
        body = (
            "<dependencyManagement><dependencies>"
            "<dependency><groupId>org.foo</groupId><artifactId>a</artifactId>"
            "<version>[1.0,2.0)</version></dependency>"
            "</dependencies></dependencyManagement>"
        )
        path = write_pom(tmp_path, "pom.xml", pom(body))
        run(tmp_path, {"dependencyVersions": {"org.foo": "1.5"}})
        assert texts(parse(path), "//m:dependency/m:version") == ["1.5"]

    def test_absent_group_is_noop(self, tmp_path):
        path = write_pom(tmp_path, "pom.xml", pom(""))
        before = path.read_bytes()
        run(tmp_path, {"dependencyVersions": {"org.nope": "1"}})
        assert path.read_bytes() == before


# ---------------------------------------------------------------------------
# removeProfileModules
# ---------------------------------------------------------------------------


class TestRemoveProfileModules:
    def test_removes_only_named_module_in_named_profile(self, tmp_path):
        body = (
            "<profiles>"
            "<profile><id>env-install</id><modules>"
            "<module>keep</module><module>drop</module>"
            "</modules></profile>"
            "<profile><id>env-dev</id><modules>"
            "<module>drop</module>"
            "</modules></profile>"
            "</profiles>"
        )
        path = write_pom(tmp_path, "pom.xml", pom(body))
        run(tmp_path, {"removeProfileModules": {"env-install": ["drop"]}})
        tree = parse(path)
        install = tree.xpath(
            "//m:profile[m:id='env-install']/m:modules/m:module/text()", namespaces=NS
        )
        dev = tree.xpath(
            "//m:profile[m:id='env-dev']/m:modules/m:module/text()", namespaces=NS
        )
        assert install == ["keep"]
        assert dev == ["drop"]

    def test_reaches_deeply_nested_pom(self, tmp_path):
        # Regression: the old shell tool lacked globstar and missed deep poms.
        body = (
            "<profiles><profile><id>p</id><modules>"
            "<module>gone</module></modules></profile></profiles>"
        )
        path = write_pom(tmp_path, "a/b/c/d/pom.xml", pom(body, artifact="deep"))
        run(tmp_path, {"removeProfileModules": {"p": ["gone"]}})
        assert parse(path).xpath("//m:module", namespaces=NS) == []


# ---------------------------------------------------------------------------
# resetBuildTimestamp
# ---------------------------------------------------------------------------


class TestResetBuildTimestamp:
    def test_creates_properties_when_missing(self, tmp_path):
        path = write_pom(tmp_path, "pom.xml", pom(""))
        run(tmp_path, {"resetBuildTimestamp": True})
        assert texts(
            parse(path), "/m:project/m:properties/m:project.build.outputTimestamp"
        ) == [pt.BUILD_TIMESTAMP]

    def test_updates_existing_without_duplicating(self, tmp_path):
        # Regression: the old xmlstarlet --subnode appended duplicates.
        body = (
            "<properties>"
            "<project.build.outputTimestamp>2024-01-01T00:00:00Z</project.build.outputTimestamp>"
            "</properties>"
        )
        path = write_pom(tmp_path, "pom.xml", pom(body))
        run(tmp_path, {"resetBuildTimestamp": True})
        run(tmp_path, {"resetBuildTimestamp": True})
        nodes = parse(path).xpath(
            "/m:project/m:properties/m:project.build.outputTimestamp", namespaces=NS
        )
        assert len(nodes) == 1
        assert nodes[0].text == pt.BUILD_TIMESTAMP


# ---------------------------------------------------------------------------
# pinDependencyVersions
# ---------------------------------------------------------------------------


class TestPinDependencyVersions:
    def test_pins_into_dependency_management(self, tmp_path):
        path = write_pom(tmp_path, "pom.xml", pom(""))
        versions = {
            "org.bouncycastle:bcutil-jdk18on": "1.80.2",
            "org.bouncycastle:bcprov-jdk18on": "1.80",
        }
        run(tmp_path, {"pinDependencyVersions": versions})
        tree = parse(path)
        entries = tree.xpath(
            "/m:project/m:dependencyManagement/m:dependencies/m:dependency", namespaces=NS
        )
        got = {
            (n.find("m:groupId", NS).text, n.find("m:artifactId", NS).text): n.find(
                "m:version", NS
            ).text
            for n in entries
        }
        assert got == {
            ("org.bouncycastle", "bcutil-jdk18on"): "1.80.2",
            ("org.bouncycastle", "bcprov-jdk18on"): "1.80",
        }

    def test_empty_map_is_noop(self, tmp_path):
        path = write_pom(tmp_path, "pom.xml", pom(""))
        before = path.read_bytes()
        run(tmp_path, {"pinDependencyVersions": {}})
        assert path.read_bytes() == before

    def test_skips_already_managed(self, tmp_path):
        body = (
            "<dependencyManagement><dependencies><dependency>"
            "<groupId>org.bouncycastle</groupId><artifactId>bcutil-jdk18on</artifactId>"
            "<version>1.70</version></dependency></dependencies></dependencyManagement>"
        )
        path = write_pom(tmp_path, "pom.xml", pom(body))
        run(tmp_path, {"pinDependencyVersions": {"org.bouncycastle:bcutil-jdk18on": "1.80.2"}})
        assert texts(parse(path), "//m:dependencyManagement//m:version") == ["1.70"]

    def test_only_top_level_poms(self, tmp_path):
        write_pom(tmp_path, "pom.xml", pom(""))
        child = write_pom(
            tmp_path,
            "child/pom.xml",
            pom("", artifact="child", parent=("com.example", "root", "1.0.0")),
        )
        run(tmp_path, {"pinDependencyVersions": {"g:a": "1"}})
        assert parse(child).xpath("//m:dependencyManagement", namespaces=NS) == []

    def test_module_with_external_parent_is_top_level(self, tmp_path):
        child = write_pom(
            tmp_path,
            "child/pom.xml",
            pom("", artifact="child", parent=("org.external", "parent", "1")),
        )
        run(tmp_path, {"pinDependencyVersions": {"g:a": "1"}})
        entries = parse(child).xpath(
            "//m:dependencyManagement//m:dependency", namespaces=NS
        )
        assert len(entries) == 1

    def test_idempotent(self, tmp_path):
        path = write_pom(tmp_path, "pom.xml", pom(""))
        rules = {"pinDependencyVersions": {"g:a": "1", "g:b": "2"}}
        run(tmp_path, rules)
        first = path.read_bytes()
        run(tmp_path, rules)
        assert path.read_bytes() == first


# ---------------------------------------------------------------------------
# pluginVersions
# ---------------------------------------------------------------------------


class TestPluginVersions:
    def test_updates_matching_plugin(self, tmp_path):
        body = (
            "<build><plugins>"
            "<plugin><groupId>org.apache.maven.plugins</groupId>"
            "<artifactId>maven-javadoc-plugin</artifactId><version>3.0</version></plugin>"
            "<plugin><groupId>org.apache.maven.plugins</groupId>"
            "<artifactId>maven-jar-plugin</artifactId><version>3.0</version></plugin>"
            "</plugins></build>"
        )
        path = write_pom(tmp_path, "pom.xml", pom(body))
        run(
            tmp_path,
            {
                "pluginVersions": [
                    {
                        "groupId": "org.apache.maven.plugins",
                        "artifactId": "maven-javadoc-plugin",
                        "version": "3.11.2",
                    }
                ]
            },
        )
        tree = parse(path)
        assert texts(
            tree, "//m:plugin[m:artifactId='maven-javadoc-plugin']/m:version"
        ) == ["3.11.2"]
        assert texts(tree, "//m:plugin[m:artifactId='maven-jar-plugin']/m:version") == [
            "3.0"
        ]


# ---------------------------------------------------------------------------
# addXmlDoclet
# ---------------------------------------------------------------------------


class TestAddXmlDoclet:
    def test_creates_full_plugin_structure(self, tmp_path):
        path = write_pom(tmp_path, "pom.xml", pom(""))
        run(tmp_path, {"addXmlDoclet": {"javadocVersion": "3.11.2", "xmlDocletVersion": "2.0.3"}})
        tree = parse(path)
        plugin = tree.xpath(
            "/m:project/m:build/m:plugins/m:plugin[m:artifactId='maven-javadoc-plugin']",
            namespaces=NS,
        )
        assert len(plugin) == 1
        p = plugin[0]
        assert p.find("m:version", NS).text == "3.11.2"
        assert p.find("m:executions/m:execution/m:id", NS).text == "xml-doclet"
        assert p.find("m:executions/m:execution/m:phase", NS).text == "prepare-package"
        assert p.find("m:executions/m:execution/m:goals/m:goal", NS).text == "javadoc"
        cfg = p.find("m:executions/m:execution/m:configuration", NS)
        assert cfg.find("m:doclet", NS).text == "com.manticore.tools.xmldoclet.XmlDoclet"
        assert cfg.find("m:useStandardDocletOptions", NS).text == "false"
        da = cfg.find("m:docletArtifact", NS)
        assert da.find("m:artifactId", NS).text == "xml-doclet"
        assert da.find("m:version", NS).text == "2.0.3"
        assert da.find("m:classifier", NS).text == "all"

    def test_replaces_existing_javadoc_plugin(self, tmp_path):
        body = (
            "<build><plugins><plugin>"
            "<groupId>org.apache.maven.plugins</groupId>"
            "<artifactId>maven-javadoc-plugin</artifactId><version>2.0</version>"
            "</plugin></plugins></build>"
        )
        path = write_pom(tmp_path, "pom.xml", pom(body))
        run(tmp_path, {"addXmlDoclet": {"javadocVersion": "3.11.2", "xmlDocletVersion": "2.0.3"}})
        tree = parse(path)
        plugins = tree.xpath(
            "//m:build/m:plugins/m:plugin[m:artifactId='maven-javadoc-plugin']", namespaces=NS
        )
        assert len(plugins) == 1
        assert plugins[0].find("m:version", NS).text == "3.11.2"

    def test_requires_root_pom(self, tmp_path):
        write_pom(tmp_path, "sub/pom.xml", pom("", artifact="sub"))
        with pytest.raises(pt.RulesError, match="root pom.xml"):
            run(tmp_path, {"addXmlDoclet": {"javadocVersion": "3", "xmlDocletVersion": "2"}})


# ---------------------------------------------------------------------------
# resetMetadataTimestamp
# ---------------------------------------------------------------------------


class TestResetMetadataTimestamp:
    def test_resets_nested_metadata(self, tmp_path):
        meta = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            "<metadata><groupId>g</groupId><artifactId>a</artifactId>"
            "<versioning><latest>1</latest><lastUpdated>20240101000000</lastUpdated>"
            "</versioning></metadata>"
        )
        path = tmp_path / "repo" / "g" / "a" / "maven-metadata-local.xml"
        path.parent.mkdir(parents=True)
        path.write_text(meta, encoding="utf-8")
        run(tmp_path, {"resetMetadataTimestamp": True})
        tree = etree.parse(str(path))
        assert tree.xpath("/metadata/versioning/lastUpdated/text()") == [
            pt.METADATA_TIMESTAMP
        ]
        assert tree.xpath("/metadata/versioning/latest/text()") == ["1"]

    def test_no_metadata_is_noop(self, tmp_path):
        write_pom(tmp_path, "pom.xml", pom(""))
        run(tmp_path, {"resetMetadataTimestamp": True})  # must not raise


# ---------------------------------------------------------------------------
# Cross-cutting invariants
# ---------------------------------------------------------------------------


class TestInvariants:
    def test_canonical_order_independent_of_json_key_order(self, tmp_path):
        body = (
            "<build><plugins><plugin>"
            "<groupId>org.apache.maven.plugins</groupId>"
            "<artifactId>maven-javadoc-plugin</artifactId><version>3.0</version>"
            "</plugin></plugins></build>"
        )
        rules = {
            "javaVersion": "17",
            "pkgVersion": "5.0",
            "pluginVersions": [
                {
                    "groupId": "org.apache.maven.plugins",
                    "artifactId": "maven-javadoc-plugin",
                    "version": "3.11.2",
                }
            ],
            "addXmlDoclet": {"javadocVersion": "3.11.2", "xmlDocletVersion": "2.0.3"},
        }
        a = tmp_path / "a"
        b = tmp_path / "b"
        write_pom(a, "pom.xml", pom(body))
        write_pom(b, "pom.xml", pom(body))
        # Forward vs reversed key order must produce identical bytes.
        pt.apply_rules(a, rules)
        pt.apply_rules(b, dict(reversed(list(rules.items()))))
        assert (a / "pom.xml").read_bytes() == (b / "pom.xml").read_bytes()

    def test_untouched_pom_is_byte_identical(self, tmp_path):
        compiler = (
            "<build><plugins><plugin>"
            "<configuration><source>1.8</source></configuration>"
            "</plugin></plugins></build>"
        )
        write_pom(tmp_path, "pom.xml", pom(compiler))
        untouched = write_pom(tmp_path, "other/pom.xml", pom("", artifact="other"))
        before = untouched.read_bytes()
        run(tmp_path, {"javaVersion": "17"})
        assert untouched.read_bytes() == before

    def test_full_rules_idempotent(self, tmp_path):
        body = (
            "<dependencies><dependency><groupId>org.foo</groupId>"
            "<artifactId>a</artifactId><version>1.0</version></dependency></dependencies>"
            "<profiles><profile><id>p</id><modules><module>m</module></modules></profile></profiles>"
        )
        write_pom(tmp_path, "pom.xml", pom(body))
        write_pom(
            tmp_path,
            "child/pom.xml",
            pom("", artifact="child", parent=("com.example", "root", "1.0.0")),
        )
        rules = {
            "javaVersion": "17",
            "pkgVersion": "5.0",
            "dependencyVersions": {"org.foo": "1.9"},
            "removeProfileModules": {"p": ["m"]},
            "resetBuildTimestamp": True,
            "pinDependencyVersions": {"org.bouncycastle:bcutil-jdk18on": "1.80.2"},
            "pluginVersions": [
                {
                    "groupId": "org.apache.maven.plugins",
                    "artifactId": "maven-javadoc-plugin",
                    "version": "3.11.2",
                }
            ],
            "addXmlDoclet": {"javadocVersion": "3.11.2", "xmlDocletVersion": "2.0.3"},
        }
        run(tmp_path, rules)
        snapshot = {p: p.read_bytes() for p in tmp_path.rglob("pom.xml")}
        run(tmp_path, rules)
        for path, data in snapshot.items():
            assert path.read_bytes() == data, f"{path} changed on second run"

    def test_group_id_inherited_from_parent_for_coordinates(self, tmp_path):
        # A module that omits groupId inherits it from parent; it must still be
        # recognized as part of the reactor (not top-level).
        write_pom(tmp_path, "pom.xml", pom("", group="com.example", artifact="root"))
        child_body = pom("", artifact="child", parent=("com.example", "root", "1.0.0"))
        # Strip the child's own groupId so it must fall back to parent/groupId.
        child_body = child_body.replace("<groupId>com.example</groupId><artifactId>child", "<artifactId>child")
        child = write_pom(tmp_path, "child/pom.xml", child_body)
        run(tmp_path, {"pinDependencyVersions": {"g:a": "1"}})
        assert parse(child).xpath("//m:dependencyManagement", namespaces=NS) == []


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


class TestCli:
    def test_success(self, tmp_path, monkeypatch):
        write_pom(tmp_path, "pom.xml", pom(""))
        rules_file = tmp_path / "rules.json"
        rules_file.write_text(json.dumps({"pkgVersion": "7.0"}), encoding="utf-8")
        monkeypatch.chdir(tmp_path)
        assert pt.main([str(rules_file)]) == 0
        assert texts(parse(tmp_path / "pom.xml"), "/m:project/m:version") == ["7.0"]

    def test_wrong_arg_count(self, tmp_path, capsys):
        assert pt.main([]) == 1
        assert "Usage" in capsys.readouterr().err

    def test_invalid_json(self, tmp_path, monkeypatch, capsys):
        bad = tmp_path / "rules.json"
        bad.write_text("{not json", encoding="utf-8")
        monkeypatch.chdir(tmp_path)
        assert pt.main([str(bad)]) == 1
        assert "pom-tools" in capsys.readouterr().err

    def test_malformed_rules(self, tmp_path, monkeypatch, capsys):
        bad = tmp_path / "rules.json"
        bad.write_text(json.dumps({"javaVersion": 17}), encoding="utf-8")
        monkeypatch.chdir(tmp_path)
        assert pt.main([str(bad)]) == 1
        assert "pom-tools" in capsys.readouterr().err

    def test_missing_rules_file(self, tmp_path, monkeypatch, capsys):
        monkeypatch.chdir(tmp_path)
        assert pt.main([str(tmp_path / "absent.json")]) == 1
        assert "pom-tools" in capsys.readouterr().err
