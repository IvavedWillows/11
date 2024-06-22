# ======================================================================= #
#  Copyright (C) 2020 - 2024 Dominik Willner <th33xitus@gmail.com>        #
#                                                                         #
#  This file is part of KIAUH - Klipper Installation And Update Helper    #
#  https://github.com/dw-0/kiauh                                          #
#                                                                         #
#  This file may be distributed under the terms of the GNU GPLv3 license  #
# ======================================================================= #

import textwrap
from enum import Enum, unique
from typing import List

from core.instance_manager.base_instance import BaseInstance
from core.menus.base_menu import print_back_footer
from utils.constants import (
    COLOR_CYAN,
    COLOR_GREEN,
    COLOR_YELLOW,
    RESET_FORMAT,
)


@unique
class DisplayType(Enum):
    SERVICE_NAME = "SERVICE_NAME"
    PRINTER_NAME = "PRINTER_NAME"


def print_instance_overview(
    instances: List[BaseInstance],
    display_type: DisplayType = DisplayType.SERVICE_NAME,
    show_headline=True,
    show_index=False,
    show_select_all=False,
):
    dialog = "╔═══════════════════════════════════════════════════════╗\n"
    if show_headline:
        d_type = (
            "Klipper instances"
            if display_type is DisplayType.SERVICE_NAME
            else "printer directories"
        )
        headline = f"{COLOR_GREEN}The following {d_type} were found:{RESET_FORMAT}"
        dialog += f"║{headline:^64}║\n"
        dialog += "╟───────────────────────────────────────────────────────╢\n"

    if show_select_all:
        select_all = f"{COLOR_YELLOW}a) Select all{RESET_FORMAT}"
        dialog += f"║ {select_all:<63}║\n"
        dialog += "║                                                       ║\n"

    for i, s in enumerate(instances):
        if display_type is DisplayType.SERVICE_NAME:
            name = s.get_service_file_name()
        else:
            name = s.data_dir
        line = f"{COLOR_CYAN}{f'{i})' if show_index else '●'} {name}{RESET_FORMAT}"
        dialog += f"║ {line:<63}║\n"
    dialog += "╟───────────────────────────────────────────────────────╢\n"

    print(dialog, end="")
    print_back_footer()


def print_select_instance_count_dialog():
    line1 = f"{COLOR_YELLOW}WARNING:{RESET_FORMAT}"
    line2 = f"{COLOR_YELLOW}Setting up too many instances may crash your system.{RESET_FORMAT}"
    dialog = textwrap.dedent(
        f"""
        ╔═══════════════════════════════════════════════════════╗
        ║ Please select the number of Klipper instances to set  ║
        ║ up. The number of Klipper instances will determine    ║
        ║ the amount of printers you can run from this host.    ║
        ║                                                       ║
        ║ {line1:<63}║
        ║ {line2:<63}║
        ╟───────────────────────────────────────────────────────╢
        """
    )[1:]

    print(dialog, end="")
    print_back_footer()


def print_select_custom_name_dialog():
    line1 = f"{COLOR_YELLOW}INFO:{RESET_FORMAT}"
    line2 = f"{COLOR_YELLOW}Only alphanumeric characters are allowed!{RESET_FORMAT}"
    dialog = textwrap.dedent(
        f"""
        ╔═══════════════════════════════════════════════════════╗
        ║ You can now assign a custom name to each instance.    ║
        ║ If skipped, each instance will get an index assigned  ║
        ║ in ascending order, starting at index '1'.            ║
        ║                                                       ║
        ║ {line1:<63}║
        ║ {line2:<63}║
        ╟───────────────────────────────────────────────────────╢
        """
    )[1:]

    print(dialog, end="")
    print_back_footer()
