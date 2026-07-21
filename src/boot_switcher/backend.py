#!/usr/bin/env python3

import subprocess
import sys
import re


def run(cmd):

    print("Running:", " ".join(cmd))

    result = subprocess.run(cmd)

    if result.returncode != 0:
        sys.exit(result.returncode)



def efiboot_output():

    result = subprocess.run(
        ["efibootmgr"],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print(result.stderr)
        sys.exit(1)

    return result.stdout



def get_boot_order():

    output = efiboot_output()

    match = re.search(
        r"BootOrder:\s*([0-9A-Fa-f,]+)",
        output
    )

    if match:
        return match.group(1).split(",")

    return []



def set_once(entry):

    run([
        "efibootmgr",
        "-n",
        entry
    ])



def set_permanent(entry):

    old_order = get_boot_order()

    new_order = [entry]

    for item in old_order:
        if item not in new_order:
            new_order.append(item)


    run([
        "efibootmgr",
        "-o",
        ",".join(new_order)
    ])



def main():

    if len(sys.argv) < 3:

        print(
            """
Usage:

One time:
    boot-switcher.py ENTRY_ID once

Permanent:
    boot-switcher.py ENTRY_ID permanent
"""
        )

        return



    entry = sys.argv[1]
    mode = sys.argv[2].lower()



    if mode == "once":

        set_once(entry)


    elif mode == "permanent":

        set_permanent(entry)


    else:

        print("Unknown mode")
        sys.exit(1)



if __name__ == "__main__":
    main()
