import QtQuick
import QtTest

Item {
    width: 600; height: 400
    NavigationHarness { id: panel }
    TextInput { id: outside; y: 350; width: 200; height: 30; activeFocusOnTab: true }

    TestCase {
        name: "SearchNavigation"
        when: windowShown

        function init() {
            panel.dismiss();
            panel.panelState.lastHomeTab = "desktop";
            panel.panelState.ready = true;
            panel.query = "";
            panel.openOnScreen({name: "mock"});
            tryCompare(panel.input, "activeFocus", true);
        }

        function test_real_tab_routes_before_default_focus_navigation() {
            keyClick(Qt.Key_Tab);
            compare(panel.homeTab, "controls");
            verify(panel.input.activeFocus);
            keyClick(Qt.Key_Backtab);
            compare(panel.homeTab, "desktop");
            verify(panel.input.activeFocus);
            keyClick(Qt.Key_Tab, Qt.ShiftModifier);
            compare(panel.homeTab, "controls");
            verify(panel.input.activeFocus);
        }

        function test_typing_and_escape_return_to_original_tab() {
            panel.selectHome("controls");
            keyClick(Qt.Key_A);
            compare(panel.query, "a");
            compare(panel.activePage, panel.pageIndexes.search);
            keyClick(Qt.Key_Escape);
            compare(panel.query, "");
            compare(panel.activePage, panel.pageIndexes.controls);
            keyClick(Qt.Key_Escape);
            verify(!panel.open);
        }

        function test_explicit_selection_survives_deferred_query_reset() {
            panel.query = "app";
            // Exercise an explicit navigation request before the event loop
            // drains the queued query reset, without QTest's implicit waits.
            panel.moveSelection(1);
            compare(panel.selectedIndex, 1);
            wait(1);
            compare(panel.selectedIndex, 1);
            compare(panel.selectedKey, "second");
        }

        function test_real_control_navigation_keys() {
            panel.query = "app";
            wait(1);
            keyClick(Qt.Key_N, Qt.ControlModifier);
            compare(panel.selectedIndex, 1);
            keyClick(Qt.Key_P, Qt.ControlModifier);
            compare(panel.selectedIndex, 0);
        }

        function test_details_focus_wins_and_invalid_route_does_not_mutate_state() {
            panel.returnToHome(); // Queue search focus, then navigate in the same turn.
            verify(panel.showDetails("audio"));
            tryCompare(panel.detailItem, "activeFocus", true);
            compare(panel.showDetails("invalid"), false);
            compare(panel.controlSection, "audio");
            verify(panel.detailItem.activeFocus);
        }

        function test_closed_panel_never_receives_queued_focus() {
            panel.returnToHome();
            panel.showDetails("wifi");
            panel.dismiss();
            outside.forceActiveFocus();
            wait(1);
            verify(outside.activeFocus);
        }

        function test_reopen_restores_home_without_restoring_search_or_details() {
            panel.selectHome("controls");
            panel.query = "private search";
            panel.dismiss();
            panel.openOnScreen({name: "next"});
            compare(panel.homeTab, "controls");
            compare(panel.query, "");
            compare(panel.controlSection, "");
            panel.selectHome("desktop");
            panel.showDetails("audio");
            panel.dismiss();
            panel.openOnScreen({name: "next"});
            compare(panel.activePage, panel.pageIndexes.controls);
            compare(panel.controlSection, "");
        }

        function test_late_panel_state_does_not_navigate_current_page() {
            panel.panelState.ready = false;
            panel.panelState.lastHomeTab = "controls";
            panel.panelState.ready = true;
            wait(1);
            compare(panel.homeTab, "desktop");
            panel.dismiss();
            panel.openOnScreen({name: "next"});
            compare(panel.homeTab, "controls");
        }
    }
}
