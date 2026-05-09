"""A simple CLI tool that counts words, lines, and characters in a file.

This script is used as a *build tool* — Bazel runs it during the build,
not as part of the final application. It demonstrates how custom rules
can wrap real CLI executables via ctx.actions.run().

Usage (Bazel runs this for you):
    python wordcount_tool.py --input <file> --output <report>
"""

import argparse
import json


def main():
    parser = argparse.ArgumentParser(description="Count words in a file.")
    parser.add_argument("--input", required=True, help="Path to the input file.")
    parser.add_argument("--output", required=True, help="Path to write the JSON report.")
    args = parser.parse_args()

    # Read the input file and compute stats.
    with open(args.input, "r") as f:
        content = f.read()

    stats = {
        "file": args.input,
        "lines": content.count("\n"),
        "words": len(content.split()),
        "characters": len(content),
    }

    # Write the report as JSON.
    with open(args.output, "w") as f:
        json.dump(stats, f, indent=2)


if __name__ == "__main__":
    main()
