#!/usr/bin/env python3
"""Exercise real TextInput key delivery and QML navigation bindings offscreen."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
from test_desktop_ui import test_runner


def main():
    source = Path(__file__).resolve().parents[1]
    runner = test_runner()
    launcher = (source / "components/LauncherPanel.qml").read_text()
    # Copy production state and handlers unchanged; replace only compositor and
    # service objects. No Wayland, notification daemon or real app is instantiated.
    start = launcher.index('    property bool open:')
    end = launcher.index('    visible: open ||')
    with tempfile.TemporaryDirectory(prefix="quickshell-search-tests-") as directory:
        work = Path(directory)
        shutil.copy(source / "components/EmacsInput.qml", work)
        shutil.copy(source / "tests/fixtures/tst_search_navigation.qml", work)
        (work / "NavigationHarness.qml").write_text('''import QtQuick
import QtQuick.Layouts
Item {
    id: panel
    width: 500; height: 300
    property var screen: null
    property var services: ({sink: null, player: null})
    property var searchModel: model
    property var panelState: savedPanelState
    property alias input: search
    property alias detailItem: controlDetails
    QtObject {
        id: savedPanelState
        property bool ready: true
        property string lastHomeTab: "desktop"
        function setLastHomeTab(tab) { lastHomeTab = tab; }
    }
    QtObject {
        id: model
        property var results: [{key: "first", kind: "APP"}, {key: "second", kind: "APP"}]
        function activateResult(result, terminal) { return {accepted: false, closePanel: false}; }
    }
    QtObject { id: trayMenu; function dismiss() {} }
    EmacsInput {
        id: search
        width: 400; height: 40
        activeFocusOnTab: true
        visible: !panel.showingDetails
        text: panel.query
        onTextChanged: panel.query = text
        onShortcut: event => panel.handleKey(event)
        Keys.onEscapePressed: panel.handleEscape()
    }
    StackLayout {
        y: 50; width: 400; height: 200
        currentIndex: panel.activePage
        Item { id: searchResultsPage
            function showSelection(index) {}
            function resetScroll() {}
        }
        Item { id: statusPage }
        Item { id: controlDetails; focus: visible }
        Item { id: desktopPage }
    }
''' + launcher[start:end] + '\n}\n')
        env = dict(os.environ)
        env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QT_FORCE_STDERR_LOGGING="1",
                   QML_IMPORT_PATH=str(runner.parent.parent / "lib/qt-6/qml"))
        result = subprocess.run([str(runner), "-input", str(work)], env=env, timeout=30)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
