from contextlib import contextmanager
from copy import deepcopy
from dataclasses import dataclass
import json
import os
import re
import subprocess
import sys
import threading

import toposort


LOCK_FILE = "fixed-output-derivations.lock"
VERSIONS_LOCK_FILE = "maven-dependency-versions.lock"
FIND_HASHES_RE = re.compile(
    r"^\s+specified: sha256-A{43}=\n\s+got:\s+(?P<new_hash>sha256-.{44})$",
    re.MULTILINE)
# dependency:list stdout lines look like "[INFO]    g:a:jar:1.0:compile -- module ...".
RESOLVED_DEP_RE = re.compile(r"([\w.\-]+):([\w.\-]+):jar:([\w.\-]+):(compile|runtime|test|provided)")


"""
{
  "foo": {
    "hash": "sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  },
  "bar": {
    "hash": "sha256-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "dependencies": ["foo"],
    "command": "./build-bar.sh"
  },
  "baz": {
    "hash": "sha256-cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    "dependencies": ["foo", "bar"],
    "command": "./build-baz.sh"
  }
}

"""


class LockFile:
    def __init__(self, path):
        self.path = path
        self._order = []
        self._current = -1
        self._is_open = False

    def __enter__(self):
        self._is_open = True
        with open(self.path, "r") as f:
            self.data = json.load(f)

        self._order = toposort.toposort_flatten({k: v.get("dependencies", []) for k, v in self.data.items()})

        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.flush()

    def _as_derivation(self, key):
        data = self.data[key]
        return Derivation(
            name=key,
            hash=data["hash"],
            dependencies=data.get("dependencies", []),
            command=data.get("command", ""),
            fod=data.get("fod", ""),
            _lock_file=self
        )

    def __iter__(self):
        self._current = -1
        return self

    def __next__(self):
        self._current += 1
        if self._current >= len(self._order):
            raise StopIteration
        # print("Returning", self._order[self._current])
        # print("Current", self._current)
        # print("Order", self._order)
        return self._as_derivation(self._order[self._current])

    def _clear_hash(self, key):
        new_data = deepcopy(self.data)
        new_data[key]["hash"] = ""
        self.flush(new_data)

    def update(self, derivation):
        name, contents = derivation.as_tuple()
        self.data[name] = contents
        self.flush()

    def flush(self, alternative_data=None):
        with open(self.path, "w") as f:
            json.dump(
                alternative_data if alternative_data is not None else self.data,
                f,
                indent=2)


class VersionsLockFile:
    """Maps derivation names to the exact Maven dependency versions their FOD
    resolved, as {"versions": {"groupId:artifactId": version}}."""

    def __init__(self, path):
        self.path = path
        try:
            with open(path) as f:
                self.data = json.load(f)
        except FileNotFoundError:
            self.data = {}

    def get(self, name):
        return self.data.get(name, {}).get("versions", {})

    def set(self, name, versions):
        self.data[name] = {"versions": versions}
        self.flush()

    def flush(self):
        with open(self.path, "w") as f:
            json.dump(self.data, f, indent=2, sort_keys=True)
            f.write("\n")


@dataclass
class Derivation:
    name: str
    hash: str
    dependencies: list[str]
    command: str
    fod: str
    _lock_file: LockFile

    def __post_init__(self):
        if not self.dependencies:
            self.dependencies = []

    def as_tuple(self):
        return (self.name, {
            "hash": self.hash,
            **({"dependencies": self.dependencies} if self.dependencies else {}),
            **({"command": self.command} if self.command else {}),
            **({"fod": self.fod} if self.fod else {})
        })

    @contextmanager
    def clear_hash(self):
        self._lock_file._clear_hash(self.name)
        try:
            yield
        finally:
            self._lock_file.flush()

    def build(self):
        command = f"nix build -L path:.#{self.name}" if not self.command else self.command
        match, returncode = run_command_and_analyze(command, FIND_HASHES_RE)
        if returncode != 0:
            if not match:
                raise Exception(f"Failed to build {self.name} and no hash was found in the output")
            return match.group("new_hash")
        # Build succeeded: the recorded hash may be stale or cleared, so read
        # the actual fixed-output hash from the derivation.
        return self.fod_hash() if self.fod else self.hash

    def fod_hash(self):
        drv = subprocess.run(
            ["nix", "path-info", "--derivation", f"path:.#{self.fod}"],
            check=True, capture_output=True, text=True).stdout.strip()
        show = subprocess.run(
            ["nix", "derivation", "show", drv],
            check=True, capture_output=True, text=True).stdout
        return json.loads(show)["derivations"][os.path.basename(drv)]["outputs"]["out"]["hash"]

    def build_and_capture(self, versions_lock):
        """Build the FOD, capture its resolved dependency versions, and if they
        changed, pin them and rebuild so the recorded hash matches the pinned
        resolution.  Returns the final hash."""
        hash = self.build()
        if not self.fod:
            return hash
        # The first build ran with a cleared hash and failed the fixed-output
        # check.  Record the hash it reported so the FOD is buildable and its
        # output (with the resolution manifest) can be inspected.
        self.update_hash(hash)
        versions = self.capture_versions()
        if versions_lock.get(self.name) == versions:
            return hash
        versions_lock.set(self.name, versions)
        # The source derivation now pins the captured versions, so the FOD
        # input changes and must be rebuilt to obtain the matching hash.
        self._lock_file._clear_hash(self.name)
        return self.build()

    def capture_versions(self):
        out = subprocess.run(
            ["nix", "build", "--no-link", "--print-out-paths", f"path:.#{self.fod}"],
            check=True, capture_output=True, text=True).stdout.strip()
        with open(f"{out}/resolved-dependencies.txt") as f:
            manifest = f.read()
        versions = {}
        conflicts = {}
        for line in manifest.splitlines():
            m = RESOLVED_DEP_RE.search(line)
            if not m:
                continue
            group, artifact, version, _scope = m.groups()
            if group.startswith("es.gob.afirma"):
                continue  # reactor modules, built from source not downloaded
            coordinate = f"{group}:{artifact}"
            if coordinate in versions and versions[coordinate] != version:
                conflicts.setdefault(coordinate, {versions[coordinate]}).add(version)
            versions[coordinate] = version
        if conflicts:
            raise Exception(
                f"{self.name}: resolved graph has multiple versions for "
                f"{sorted(conflicts)}; cannot pin a single version")
        return versions

    def update_hash(self, new_hash):
        self.hash = new_hash
        self._lock_file.update(self)


def read_stream(stream, output_list, write_func):
    """
    Reads from `stream` line-by-line, writes each line via `write_func`,
    and appends each line to `output_list`.
    """
    try:
        for line in iter(stream.readline, ''):  # read until EOF
            if not line:
                break
            write_func(line)
            output_list.append(line)
    finally:
        stream.close()


def run_command_and_analyze(cmd, pattern):
    """
    Runs `cmd` in a subprocess. Captures stdout and stderr in real-time,
    printing them as they arrive. After the process completes, searches
    for `pattern` in the captured stdout.
    """
    # Start the process
    process = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,   # or use universal_newlines=True in older Python
        bufsize=1    # line-buffered
    )

    captured_stdout = []
    captured_stderr = []

    # Create threads to read stdout and stderr
    t_out = threading.Thread(
        target=read_stream,
        args=(process.stdout, captured_stdout, sys.stdout.write),
        daemon=True
    )
    t_err = threading.Thread(
        target=read_stream,
        args=(process.stderr, captured_stderr, sys.stderr.write),
        daemon=True
    )

    # Start the threads
    t_out.start()
    t_err.start()

    # Wait for the process to finish
    # (this returns the exit code of the child process)
    returncode = process.wait()

    # Make sure the threads have finished reading
    t_out.join()
    t_err.join()

    # Join all captured lines into one string
    full_stdout = "".join(captured_stdout)
    full_stderr = "".join(captured_stderr)

    # Search for the pattern in the captured output
    match = re.search(pattern, full_stdout) or re.search(pattern, full_stderr)

    return match, returncode


def main():
    versions_lock = VersionsLockFile(VERSIONS_LOCK_FILE)
    with LockFile(LOCK_FILE) as lf:
        for derivation in lf:
            with derivation.clear_hash():
                hash = derivation.build_and_capture(versions_lock)
                derivation.update_hash(hash)
    versions_lock.flush()


if __name__ == "__main__":
    main()
