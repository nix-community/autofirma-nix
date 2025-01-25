from contextlib import contextmanager
from copy import deepcopy
from dataclasses import dataclass
import json
import re
import subprocess
import sys
import threading

import toposort


LOCK_FILE = "fixed-output-derivations.lock"
FIND_HASHES_RE = re.compile(
    r"^\s+specified: sha256-A{43}=\n\s+got:\s+(?P<new_hash>sha256-.{44})$",
    re.MULTILINE)


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

    def flush(self, alternative_data=None):
        with open(self.path, "w") as f:
            json.dump(
                alternative_data if alternative_data is not None else self.data,
                f,
                indent=2)


@dataclass
class Derivation:
    name: str
    hash: str
    dependencies: list[str]
    command: str
    _lock_file: LockFile

    def __post_init__(self):
        if not self.dependencies:
            self.dependencies = []

    def as_tuple(self):
        return (self.name, {
            "hash": self.hash,
            **({"dependencies": self.dependencies} if self.dependencies else {}),
            **({"command": self.command} if self.command else {})
        })

    @contextmanager
    def clear_hash(self):
        self._lock_file._clear_hash(self.name)
        try:
            yield
        finally:
            self._lock_file.flush()

    def build(self):
        command = f"nix build -L .#{self.name}" if not self.command else self.command
        match, returncode = run_command_and_analyze(command, FIND_HASHES_RE)
        if returncode != 0:
            if not match:
                raise Exception(f"Failed to build {self.name} and no hash was found in the output")
            else:
                return match.group("new_hash")
        else:
            return self.hash

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
    with LockFile(LOCK_FILE) as lf:
        for derivation in lf:
            with derivation.clear_hash():
                hash = derivation.build()
                derivation.update_hash(hash)


if __name__ == "__main__":
    main()
