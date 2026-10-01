#!/usr/bin/env python3
"""Bound headless checks that may keep running after a GDScript assertion fails."""
import math
import os
import signal
import subprocess
import sys


class CheckCancelled(Exception):
    def __init__(self, number): self.number = number


def cancel(number, _frame):
    raise CheckCancelled(number)


def stop_and_collect(process) -> bytes:
    try:
        if os.name == "posix": os.killpg(process.pid, signal.SIGKILL)
        else: process.kill()
    except ProcessLookupError:
        pass
    try:
        output, _ = process.communicate(timeout=5)
        return output
    except subprocess.TimeoutExpired as error:
        process.stdout.close()
        return error.output or b""


def main() -> int:
    if len(sys.argv) < 2:
        print("ERROR: Missing check command", file=sys.stderr)
        return 2
    try:
        seconds = float(os.environ.get("HERO_CHECK_TIMEOUT_SECONDS", "120"))
        if not math.isfinite(seconds) or seconds <= 0: raise ValueError
    except ValueError:
        print("ERROR: HERO_CHECK_TIMEOUT_SECONDS must be a finite positive number", file=sys.stderr)
        return 2
    try:
        process = subprocess.Popen(sys.argv[1:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   start_new_session=os.name == "posix")
    except OSError as error:
        print(f"ERROR: Cannot start check: {error}", file=sys.stderr)
        return 127
    signal.signal(signal.SIGINT, cancel)
    signal.signal(signal.SIGTERM, cancel)
    try:
        output, _ = process.communicate(timeout=seconds)
    except subprocess.TimeoutExpired:
        output = stop_and_collect(process)
        sys.stdout.buffer.write(output)
        print(f"\nERROR: Check exceeded {seconds:g} seconds; stopped the test process", file=sys.stderr)
        return 124
    except CheckCancelled as error:
        sys.stdout.buffer.write(stop_and_collect(process))
        print(f"\nERROR: Check interrupted by signal {error.number}", file=sys.stderr)
        return 128 + error.number
    sys.stdout.buffer.write(output)
    return process.returncode if process.returncode >= 0 else 128 - process.returncode


if __name__ == "__main__": sys.exit(main())
