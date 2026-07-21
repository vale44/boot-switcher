#!/usr/bin/env python3

import subprocess
import sys
import re


def run(cmd):

    print(
        "Running:",
        " ".join(cmd)
    )

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True
    )

    if result.stdout:
        print(result.stdout)

    if result.stderr:
        print(result.stderr)

    return result



def efiboot_output():

    result = run(
        [
            "efibootmgr"
        ]
    )

    if result.returncode != 0:

        raise RuntimeError(
            "Could not read EFI entries"
        )

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

    result = run(
        [
            "efibootmgr",
            "-n",
            entry
        ]
    )

    if result.returncode != 0:

        raise RuntimeError(
            "Failed setting BootNext"
        )



def set_permanent(entry):

    old_order = get_boot_order()


    new_order = [
        entry
    ]


    for item in old_order:

        if item not in new_order:

            new_order.append(item)



    result = run(
        [
            "efibootmgr",
            "-o",
            ",".join(new_order)
        ]
    )


    if result.returncode != 0:

        raise RuntimeError(
            "Failed changing BootOrder"
        )



def main():

    if len(sys.argv) < 3:

        print(
            """
Usage:

One time:
    backend.py ENTRY_ID once

Permanent:
    backend.py ENTRY_ID permanent
"""
        )

        return 1



    entry = sys.argv[1]

    mode = sys.argv[2].lower()



    try:

        if mode == "once":

            set_once(entry)


        elif mode == "permanent":

            set_permanent(entry)


        else:

            print(
                "Unknown mode"
            )

            return 1



    except Exception as e:

        print(
            "ERROR:",
            str(e)
        )

        return 1



    print(
        "SUCCESS"
    )

    return 0



if __name__ == "__main__":

    sys.exit(
        main()
    )