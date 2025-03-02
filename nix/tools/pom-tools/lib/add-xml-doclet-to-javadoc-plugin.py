import sys
import xml.etree.ElementTree as ET
from xml.dom import minidom

if len(sys.argv) != 3:
    sys.stderr.write("Usage: {} <maven-javadoc-plugin-version> <xml-doclet-version>\n".format(sys.argv[0]))
    sys.exit(1)

javadoc_version = sys.argv[1]
xml_doclet_version = sys.argv[2]

# Maven POM uses this namespace
NS = {'mvn': 'http://maven.apache.org/POM/4.0.0'}
ET.register_namespace('', NS['mvn'])

tree = ET.parse('pom.xml')
root = tree.getroot()

# Find the <build> element that's a direct child of <project>
build = root.find('mvn:build', NS)
if build is None:
    build = ET.SubElement(root, '{http://maven.apache.org/POM/4.0.0}build')

# Find the <plugins> element under <build>
plugins = build.find('mvn:plugins', NS)
if plugins is None:
    plugins = ET.SubElement(build, '{http://maven.apache.org/POM/4.0.0}plugins')

# Optionally, check if a maven-javadoc-plugin is already present and remove it
for plugin in plugins.findall('mvn:plugin', NS):
    aid = plugin.find('mvn:artifactId', NS)
    if aid is not None and aid.text == 'maven-javadoc-plugin':
        plugins.remove(plugin)

# Create the new plugin element
plugin = ET.Element('{http://maven.apache.org/POM/4.0.0}plugin')

groupId = ET.SubElement(plugin, '{http://maven.apache.org/POM/4.0.0}groupId')
groupId.text = "org.apache.maven.plugins"

artifactId = ET.SubElement(plugin, '{http://maven.apache.org/POM/4.0.0}artifactId')
artifactId.text = "maven-javadoc-plugin"

version = ET.SubElement(plugin, '{http://maven.apache.org/POM/4.0.0}version')
version.text = javadoc_version

executions = ET.SubElement(plugin, '{http://maven.apache.org/POM/4.0.0}executions')
execution = ET.SubElement(executions, '{http://maven.apache.org/POM/4.0.0}execution')

exec_id = ET.SubElement(execution, '{http://maven.apache.org/POM/4.0.0}id')
exec_id.text = "xml-doclet"

phase = ET.SubElement(execution, '{http://maven.apache.org/POM/4.0.0}phase')
phase.text = "prepare-package"

goals = ET.SubElement(execution, '{http://maven.apache.org/POM/4.0.0}goals')
goal = ET.SubElement(goals, '{http://maven.apache.org/POM/4.0.0}goal')
goal.text = "javadoc"

configuration = ET.SubElement(execution, '{http://maven.apache.org/POM/4.0.0}configuration')

useStd = ET.SubElement(configuration, '{http://maven.apache.org/POM/4.0.0}useStandardDocletOptions')
useStd.text = "false"

doclet = ET.SubElement(configuration, '{http://maven.apache.org/POM/4.0.0}doclet')
doclet.text = "com.manticore.tools.xmldoclet.XmlDoclet"

additionalOptions = ET.SubElement(configuration, '{http://maven.apache.org/POM/4.0.0}additionalOptions')
additionalOptions.text = "-d ${project.build.directory}"

docletArtifact = ET.SubElement(configuration, '{http://maven.apache.org/POM/4.0.0}docletArtifact')
da_groupId = ET.SubElement(docletArtifact, '{http://maven.apache.org/POM/4.0.0}groupId')
da_groupId.text = "com.manticore-projects.tools"
da_artifactId = ET.SubElement(docletArtifact, '{http://maven.apache.org/POM/4.0.0}artifactId')
da_artifactId.text = "xml-doclet"
da_version = ET.SubElement(docletArtifact, '{http://maven.apache.org/POM/4.0.0}version')
da_version.text = xml_doclet_version
da_classifier = ET.SubElement(docletArtifact, '{http://maven.apache.org/POM/4.0.0}classifier')
da_classifier.text = "all"

# Append the new plugin to the <plugins> element
plugins.append(plugin)

# Pretty-print and write back to pom.xml
rough_string = ET.tostring(root, 'utf-8')
# Use minidom to pretty-print
reparsed = minidom.parseString(rough_string)
pretty_xml = reparsed.toprettyxml(indent="  ")

# Remove blank lines
pretty_xml_no_blanks = "\n".join([line for line in pretty_xml.split("\n") if line.strip()])

with open('pom.xml', 'w', encoding='utf-8') as f:
    f.write(pretty_xml_no_blanks)
