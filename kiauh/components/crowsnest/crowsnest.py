# ======================================================================= #
#  Copyright (C) 2020 - 2024 Dominik Willner <th33xitus@gmail.com>        #
#                                                                         #
#  This file is part of KIAUH - Klipper Installation And Update Helper    #
#  https://github.com/dw-0/kiauh                                          #
#                                                                         #
#  This file may be distributed under the terms of the GNU GPLv3 license  #
# ======================================================================= #
from __future__ import annotations

import shutil
import time
from pathlib import Path
from subprocess import CalledProcessError, run
from typing import List

from components.crowsnest import CROWSNEST_BACKUP_DIR, CROWSNEST_DIR, CROWSNEST_REPO
from components.klipper.klipper import Klipper
from core.backup_manager.backup_manager import BackupManager
from core.instance_manager.instance_manager import InstanceManager
from core.settings.kiauh_settings import KiauhSettings
from utils.common import (
    check_install_dependencies,
    get_install_status,
)
from utils.constants import CURRENT_USER
from utils.git_utils import (
    git_clone_wrapper,
    git_pull_wrapper,
)
from utils.input_utils import get_confirm
from utils.logger import DialogType, Logger
from utils.sys_utils import (
    cmd_sysctl_service,
    parse_packages_from_file,
)
from utils.types import ComponentStatus


def install_crowsnest() -> None:
    # Step 1: Clone crowsnest repo
    git_clone_wrapper(CROWSNEST_REPO, CROWSNEST_DIR, "master")

    # Step 2: Install dependencies
    check_install_dependencies(["make"])

    # Step 3: Check for Multi Instance
    im = InstanceManager(Klipper)
    instances: List[Klipper] = im.instances

    if len(instances) > 1:
        print_multi_instance_warning(instances)

        if not get_confirm("Do you want to continue with the installation?"):
            Logger.print_info("Crowsnest installation aborted!")
            return

        Logger.print_status("Launching crowsnest's install configurator ...")
        time.sleep(3)
        configure_multi_instance()

    # Step 4: Launch crowsnest installer
    Logger.print_status("Launching crowsnest installer ...")
    Logger.print_info("Installer will prompt you for sudo password!")
    try:
        run(
            f"sudo make install BASE_USER={CURRENT_USER}",
            cwd=CROWSNEST_DIR,
            shell=True,
            check=True,
        )
    except CalledProcessError as e:
        Logger.print_error(f"Something went wrong! Please try again...\n{e}")
        return


def print_multi_instance_warning(instances: List[Klipper]) -> None:
    _instances = [f"● {instance.data_dir_name}" for instance in instances]
    Logger.print_dialog(
        DialogType.WARNING,
        [
            "Multi instance install detected!",
            "\n\n",
            "Crowsnest is NOT designed to support multi instances. A workaround "
            "for this is to choose the most used instance as a 'master' and use "
            "this instance to set up your 'crowsnest.conf' and steering it's service.",
            "\n\n",
            "The following instances were found:",
            *_instances,
        ],
        end="",
    )


def configure_multi_instance() -> None:
    config = Path(CROWSNEST_DIR).joinpath("tools/.config")
    try:
        run(
            "make config",
            cwd=CROWSNEST_DIR,
            shell=True,
            check=True,
        )
    except CalledProcessError as e:
        Logger.print_error(f"Something went wrong! Please try again...\n{e}")
        if config.exists():
            Path.unlink(config)
        return

    if not config.exists():
        Logger.print_error("Generating .config failed, installation aborted")


def update_crowsnest() -> None:
    try:
        cmd_sysctl_service("crowsnest", "stop")

        if not CROWSNEST_DIR.exists():
            git_clone_wrapper(CROWSNEST_REPO, CROWSNEST_DIR, "master")
        else:
            Logger.print_status("Updating Crowsnest ...")

            settings = KiauhSettings()
            if settings.kiauh.backup_before_update:
                bm = BackupManager()
                bm.backup_directory(
                    "crowsnest",
                    source=CROWSNEST_DIR,
                    target=CROWSNEST_BACKUP_DIR,
                )

            git_pull_wrapper(CROWSNEST_REPO, CROWSNEST_DIR)

            script = CROWSNEST_DIR.joinpath("tools/install.sh")
            deps = parse_packages_from_file(script)
            check_install_dependencies(deps)

        cmd_sysctl_service("crowsnest", "restart")

        Logger.print_ok("Crowsnest updated successfully.", end="\n\n")
    except CalledProcessError as e:
        Logger.print_error(f"Something went wrong! Please try again...\n{e}")
        return


def get_crowsnest_status() -> ComponentStatus:
    files = [
        Path("/usr/local/bin/crowsnest"),
        Path("/etc/logrotate.d/crowsnest"),
        Path("/etc/systemd/system/crowsnest.service"),
    ]
    return get_install_status(CROWSNEST_DIR, files=files)


def remove_crowsnest() -> None:
    if not CROWSNEST_DIR.exists():
        Logger.print_info("Crowsnest does not seem to be installed! Skipping ...")
        return

    try:
        run(
            "make uninstall",
            cwd=CROWSNEST_DIR,
            shell=True,
            check=True,
        )
    except CalledProcessError as e:
        Logger.print_error(f"Something went wrong! Please try again...\n{e}")
        return

    Logger.print_status("Removing crowsnest directory ...")
    shutil.rmtree(CROWSNEST_DIR)
    Logger.print_ok("Directory removed!")
