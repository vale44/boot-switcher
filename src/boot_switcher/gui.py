#!/usr/bin/env python3

import sys
import os
import re
import subprocess
import time

from PySide6.QtWidgets import (
    QApplication,
    QWidget,
    QLabel,
    QPushButton,
    QRadioButton,
    QCheckBox,
    QGroupBox,
    QVBoxLayout,
    QHBoxLayout,
    QGridLayout,
    QScrollArea,
    QDialog,
    QTextEdit,
    QButtonGroup,
    QPlainTextEdit,
)

from PySide6.QtCore import Qt


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.join(
    BASE_DIR,
    "backend.py"
)


def get_efi_entries():

    entries = []
    default_id = None

    try:
        output = subprocess.check_output(
            ["efibootmgr", "-v"],
            text=True
        )

    except Exception:
        return [], None


    order = re.search(
        r"BootOrder:\s*([0-9A-Fa-f,]+)",
        output
    )

    if order:
        default_id = order.group(1).split(",")[0]


    current = None

    for line in output.splitlines():

        match = re.match(
            r"Boot([0-9A-Fa-f]{4})\*?\s+(.*)",
            line
        )

        if match:

            if current:
                entries.append(current)

            current = {
                "id": match.group(1),
                "name": match.group(2).split("HD(")[0].strip(),
                "raw": match.group(2)
            }

        elif current and line.strip():

            current["raw"] += "\n" + line.strip()


    if current:
        entries.append(current)


    entries = [
        e for e in entries
        if "PXE" not in e["name"]
    ]

    return entries, default_id



def get_current_efi():

    try:
        return subprocess.check_output(
            ["efibootmgr"],
            text=True
        )

    except Exception:
        return ""

def add_log(widget, message):

    if hasattr(widget, "log_box"):

        widget.log_box.appendPlainText(
            message
        )

def log(widget, text):

    if hasattr(widget, "console_text"):

        widget.console_text.appendPlainText(
            text
        )



class InfoDialog(QDialog):

    def __init__(self, entry):

        super().__init__()

        self.setWindowTitle(
            "Boot Entry Information"
        )

        self.resize(
            700,
            500
        )


        layout = QVBoxLayout()


        display_name = entry["name"]

        if len(display_name) > 50:
            display_name = display_name[:47] + "..."

        title = QLabel(
            display_name
        )

        title.setWordWrap(True)

        title.setStyleSheet(
            """
            font-size:24px;
            font-weight:bold;
            """
        )


        text = QTextEdit()

        text.setReadOnly(True)

        text.setText(
            f"""
EFI ID:
{entry['id']}


Name:
{entry['name']}


Raw firmware entry:

{entry['raw']}
"""
        )


        layout.addWidget(title)
        layout.addWidget(text)

        self.setLayout(layout)



class BootSwitcher(QWidget):

    def __init__(self):

        super().__init__()

        self.setWindowTitle(
            "Boot Switcher"
        )

        self.resize(
            850,
            600
        )

        self.setMinimumSize(
            700,
            500
        )


        self.entries, self.default_id = get_efi_entries()

        self.selected = None


        self.radio_group = QButtonGroup(
            self
        )

        self.radio_group.setExclusive(True)


        self.setup_ui()



    def setup_ui(self):

        main = QVBoxLayout()


        title = QLabel(
            "Boot Switcher"
        )

        title.setAlignment(
            Qt.AlignCenter
        )

        title.setStyleSheet(
            """
            font-size:28px;
            font-weight:bold;
            """
        )


        main.addWidget(title)



        os_group = QGroupBox(
            "Available Operating Systems"
        )


        os_layout = QVBoxLayout()


        scroll = QScrollArea()

        scroll.setWidgetResizable(True)


        container = QWidget()

        grid = QGridLayout()

        grid.setSpacing(4)


        for i, entry in enumerate(self.entries):

            row = QWidget()


            row_layout = QHBoxLayout()

            row_layout.setContentsMargins(
                4,
                2,
                4,
                2
            )


            display_name = entry["name"]

            if len(display_name) > 30:
                display_name = display_name[:27] + "..."

            radio = QRadioButton(
                display_name
            )


            radio.setStyleSheet(
                """
                QRadioButton {
                    font-size:18px;
                    spacing:8px;
                }

                QRadioButton::indicator {
                    width:20px;
                    height:20px;
                    border:2px solid #1976d2;
                    border-radius:10px;
                }

                QRadioButton::indicator:checked {
                    background:#1976d2;
                }
                """
            )


            if entry["id"].lower() == str(self.default_id).lower():

                radio.setChecked(True)
                self.selected = entry


            self.radio_group.addButton(
                radio
            )


            radio.clicked.connect(
                lambda checked, e=entry:
                self.select(e)
            )


            info = QPushButton(
                "ⓘ"
            )

            info.setFixedSize(
                32,
                28
            )


            info.clicked.connect(
                lambda checked, e=entry:
                self.show_info(e)
            )


            row_layout.addWidget(
                radio
            )

            row_layout.addStretch()

            row_layout.addWidget(
                info
            )


            row.setLayout(
                row_layout
            )


            grid.addWidget(
                row,
                i // 2,
                i % 2
            )


        container.setLayout(grid)

        scroll.setWidget(container)


        os_layout.addWidget(scroll)

        os_group.setLayout(os_layout)


        main.addWidget(
            os_group,
            1
        )



        behaviour = QGroupBox(
            "Behaviour"
        )


        behaviour_layout = QVBoxLayout()


        self.immediate = QCheckBox(
            "Reboot immediately"
        )


        self.permanent = QCheckBox(
            "Make permanent default"
        )


        self.bios = QCheckBox(
        "Reboot into BIOS / UEFI firmware"
        )


        checkbox_style = """

        QCheckBox {
            font-size:18px;
            spacing:10px;
        }

        QCheckBox::indicator {
            width:22px;
            height:22px;
            border:2px solid #1976d2;
            border-radius:4px;
        }

        QCheckBox::indicator:checked {
            background:#1976d2;
        }

        """


        self.immediate.setStyleSheet(
            checkbox_style
        )

        self.permanent.setStyleSheet(
            checkbox_style
        )

        self.bios.setStyleSheet(
            checkbox_style
        )

        behaviour_layout.addWidget(
            self.immediate
        )

        behaviour_layout.addWidget(
            self.permanent
        )

        behaviour_layout.addWidget(
            self.bios
        )


        behaviour.setLayout(
            behaviour_layout
        )


        main.addWidget(
            behaviour
        )



        bottom = QHBoxLayout()


        self.status = QLabel(
            "Ready"
        )

        self.log_box = QPlainTextEdit()

        self.log_box.setReadOnly(True)

        self.log_box.setMaximumHeight(
            180
        )

        self.log_box.hide()


        self.show_log = QPushButton(
            "Show Log"
        )


        self.show_log.clicked.connect(
            self.toggle_log
        )


        apply = QPushButton(
            "APPLY CHANGES"
        )


        apply.clicked.connect(
            self.apply_changes
        )


        bottom.addWidget(
            self.status
        )

        bottom.addWidget(
            self.show_log
        )

        bottom.addStretch()


        bottom.addWidget(
            apply
        )


        main.addWidget(
            self.log_box
        )


        main.addLayout(
            bottom
        )


        self.setLayout(
            main
        )


    def keyPressEvent(self, event):

        if event.key() == Qt.Key_Escape:
            self.close()

        else:
            super().keyPressEvent(event)


    def select(self, entry):

        self.selected = entry

        self.status.setText(
            f"Selected: {entry['name']}"
        )

        add_log(
            self,
            f"Selected: {entry['name']} ({entry['id']})"
        )



    def show_info(self, entry):

        InfoDialog(entry).exec()



    def toggle_log(self):

        if self.log_box.isVisible():

            self.log_box.hide()

            self.show_log.setText(
                "Show Log"
            )

        else:

            self.log_box.show()

            self.show_log.setText(
                "Hide Log"
            )



    def apply_changes(self):

        if self.bios.isChecked():

            self.status.setText(
                "Rebooting into firmware setup..."
            )

            add_log(
                self,
                "Requesting BIOS / UEFI reboot"
            )

            QApplication.processEvents()

            time.sleep(2)

            subprocess.Popen(
                [
                    "systemctl",
                    "reboot",
                    "--firmware-setup"
                ]
            )

            return



        if not self.selected:

            self.status.setText(
                "No OS selected"
            )

            add_log(
                self,
                "ERROR: No OS selected"
            )

            return



        mode = (
            "permanent"
            if self.permanent.isChecked()
            else
            "once"
        )


        add_log(
            self,
            f"Applying {mode} boot change"
        )


        try:

            result = subprocess.run(
                [
                    "pkexec",
                    sys.executable,
                    BACKEND,
                    self.selected["id"],
                    mode
                ],
                capture_output=True,
                text=True
            )


            if result.stdout:

                add_log(
                    self,
                    result.stdout
                )


            if result.stderr:

                add_log(
                    self,
                    result.stderr
                )


            if result.returncode != 0:

                self.status.setText(
                    "EFI change cancelled or failed"
                )

                add_log(
                    self,
                    "Backend returned an error"
                )

                return


        except Exception as e:

            self.status.setText(
                "Error: " + str(e)
            )

            add_log(
                self,
                "Exception: " + str(e)
            )

            return



        self.status.setText(
            "Checking EFI change..."
        )

        add_log(
            self,
            "Checking EFI state..."
        )

        QApplication.processEvents()


        time.sleep(2)


        efi = get_current_efi()


        add_log(
            self,
            efi
        )


        success = False


        if mode == "permanent":

            match = re.search(
                r"BootOrder:\s*([0-9A-Fa-f,]+)",
                efi
            )

            if match:

                first = match.group(1).split(",")[0]

                if first.lower() == self.selected["id"].lower():

                    success = True


        else:

            match = re.search(
                r"BootNext:\s*([0-9A-Fa-f]+)",
                efi
            )

            if match:

                if match.group(1).lower() == self.selected["id"].lower():

                    success = True



        if success:

            self.status.setText(
                f"✓ {self.selected['name']} applied successfully"
            )

            add_log(
                self,
                f"SUCCESS: {self.selected['name']} applied"
            )


            if self.immediate.isChecked():

                self.status.setText(
                    "Rebooting..."
                )

                add_log(
                    self,
                    "Rebooting system"
                )

                QApplication.processEvents()

                time.sleep(2)

                subprocess.Popen(
                    [
                        "systemctl",
                        "reboot"
                    ]
                )


        else:

            self.status.setText(
                "✗ EFI verification failed - reboot cancelled"
            )

            add_log(
                self,
                "ERROR: EFI verification failed"
            )



def main():

    app = QApplication(sys.argv)

    window = BootSwitcher()

    window.show()

    sys.exit(
        app.exec()
    )


if __name__ == "__main__":

    main()