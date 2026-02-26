#!/usr/bin/env python3
import sys
import json
import xml.etree.ElementTree as ET
import html
import subprocess


def html_to_markdown(html_content):
    """
    Convert HTML content to strict markdown using pandoc.
    Uses stdin/stdout instead of temporary files.
    """
    if not html_content.strip():
        return ""

    try:
        process = subprocess.Popen(
            ["pandoc", "--from=html", "--to=markdown_strict"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = process.communicate(input=html_content)

        if process.returncode != 0:
            print(f"Error converting HTML to markdown: {stderr}",
                  file=sys.stderr)
            return html_content

        return stdout.strip()
    except Exception as e:
        print(f"Failed to convert HTML to markdown: {e}", file=sys.stderr)
        return html_content


def load_properties(properties_file):
    """
    Load properties from a Java properties file,
    skipping comments and duplicate lines.
    Trims whitespace from keys and values.
    """
    props = {}
    seen_lines = set()

    with open(properties_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            # Skip lines that start with '#' or don't contain '='
            if not line or line.startswith('#') or '=' not in line:
                continue
            # Only process unique lines
            if line in seen_lines:
                continue
            seen_lines.add(line)

            # Split at the first '='
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip() if value is not None else ""
            props[key] = value

    return props


def load_xml_descriptions(xml_file):
    """
    Parse the XML file and return a mapping of preference
    constants to descriptions.
    """
    tree = ET.parse(xml_file)
    root = tree.getroot()

    pref_info = {}
    for field in root.findall(".//field"):
        constant_elem = field.find("constant")
        comment_elem = field.find("comment")

        if constant_elem is None or constant_elem.text is None:
            continue

        # Remove surrounding quotes from constant text and trim whitespace
        constant_text = constant_elem.text.strip().strip('"')

        # Extract and unescape comment text
        comment_text = ""
        if comment_elem is not None:
            # Combine text and tail if present (to capture inner tags' text)
            comment_text = ''.join(comment_elem.itertext()).strip()
            comment_text = html.unescape(comment_text)
            # Convert HTML to markdown
            comment_text = html_to_markdown(comment_text)

        pref_info[constant_text] = comment_text

    return pref_info


def main(properties_file, xml_file):
    # 1. Load properties
    master_prefs = load_properties(properties_file)

    # 2. Load XML descriptions
    pref_info = load_xml_descriptions(xml_file)

    # 3. Merge preferences with descriptions
    merged_prefs = {}
    for key, default_value in master_prefs.items():
        description = pref_info.get(key, "")
        merged_prefs[key] = {
            "default": default_value,
            "description": description
        }

    # 4. Output merged JSON
    print(json.dumps(merged_prefs, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(
            (f"Usage: {sys.argv[0]} "
             "preferences.properties "
             "preferences-javadoc.xml"),
            file=sys.stderr)
        sys.exit(1)

    main(sys.argv[1], sys.argv[2])
