#!/usr/bin/env python3
"""Run actual desktop QML against mock services, entirely offscreen.

Only Quickshell-specific rendering types are substituted. Production page,
delegate, and action handlers are copied unchanged into a temporary QML module.
Uses qmltestrunner from PATH, QMLTESTRUNNER, or the installed Quickshell Nix closure.
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def test_runner():
    override = os.environ.get("QMLTESTRUNNER")
    if override:
        return Path(override).resolve()
    installed = shutil.which("qmltestrunner")
    if installed:
        return Path(installed).resolve()
    quickshell = shutil.which("quickshell")
    nix_store = shutil.which("nix-store")
    if quickshell and nix_store:
        binary = Path(quickshell).resolve()
        package = next((p for p in binary.parents if p.parent == Path("/nix/store")), None)
        if package:
            try:
                closure = subprocess.check_output(
                    [nix_store, "--query", "--requisites", str(package)], text=True
                ).splitlines()
            except subprocess.CalledProcessError:
                raise SystemExit("Cannot inspect the Nix closure; set QMLTESTRUNNER to an available Qt test runner") from None
            for dependency in closure:
                candidate = Path(dependency) / "bin/qmltestrunner"
                if candidate.is_file():
                    return candidate
    raise SystemExit("qmltestrunner unavailable; run in a Qt declarative dev shell or set QMLTESTRUNNER")


def main():
    source = Path(__file__).resolve().parents[1]
    runner = test_runner()
    with tempfile.TemporaryDirectory(prefix="quickshell-desktop-tests-") as directory:
        work = Path(directory)
        for name in ("DesktopPage", "DesktopWindowCard", "ControlDetails", "ChoiceButton",
                     "GroupCard", "DeviceRow", "StatusIcon"):
            code = (source / "components" / (name + ".qml")).read_text()
            code = code.replace('import ".."', 'import "."')
            code = code.replace("import Quickshell.Widgets\n", "")
            (work / (name + ".qml")).write_text(code)
        theme = (source / "Theme.qml").read_text()
        (work / "Theme.qml").write_text(
            theme.replace("import Quickshell\n", "").replace("Scope {", "QtObject {")
        )
        (work / "IconImage.qml").write_text(
            'import QtQuick\nItem { property string source: ""; property int status: Image.Null; property real implicitSize: 20 }\n'
        )
        (work / "ClippingRectangle.qml").write_text("import QtQuick\nRectangle { clip: true }\n")
        (work / "NotificationRow.qml").write_text(
            "import QtQuick\nItem { property var style; property var entry; property bool compact; signal triggered() }\n"
        )
        fixture = (source / "tests/fixtures/tst_desktop_ui.qml").read_text()
        screenshot = os.environ.get("DESKTOP_SCREENSHOT", "")
        if screenshot:
            import json
            fixture = fixture.replace('property string screenshotPath: ""',
                                      "property string screenshotPath: " + json.dumps(screenshot))
        (work / "tst_desktop_ui.qml").write_text(fixture)
        env = os.environ.copy()
        env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
        imports = runner.parent.parent / "lib/qt-6/qml"
        completed = subprocess.run(
            [str(runner), "-import", str(imports), "-input", str(work), "-o", "-,txt"],
            env=env, timeout=45, check=False
        )
        raise SystemExit(completed.returncode)


if __name__ == "__main__":
    main()
