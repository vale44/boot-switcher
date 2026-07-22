#!/usr/bin/env python3

import sys
import os


BASE_DIR = os.path.dirname(
    os.path.abspath(__file__)
)


SRC_DIR = os.path.join(
    BASE_DIR,
    "src"
)


sys.path.insert(
    0,
    SRC_DIR
)


from boot_switcher.gui import main


if __name__ == "__main__":

    main()