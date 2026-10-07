pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: searchModel
    required property string query
    // Terminal executable and its argument separator; argv stays an array.
    property list<string> terminalCommand: ["kitty", "--"]
    readonly property var results: {
        const terms = query.trim().toLocaleLowerCase().split(/\s+/).filter(t => t);
        const matches = text => terms.every(t => text.toLocaleLowerCase().includes(t));
        const windows = ToplevelManager.toplevels.values.map(w => ({
            kind: "WINDOW", title: w.title || w.appId, detail: w.appId,
            entry: desktopEntryFor(w), target: w
        })).filter(r => matches(r.title + " " + r.detail));
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay
            && matches(a.name + " " + a.genericName + " " + a.comment + " " + a.id))
            .sort((a, b) => {
                const q = query.trim().toLocaleLowerCase();
                const score = a => q && a.name.toLocaleLowerCase().startsWith(q) ? 0 : 1;
                return score(a) - score(b) || a.name.localeCompare(b.name);
            }).map(a => ({ kind: "APP", title: a.name, detail: a.genericName || a.comment || a.id,
                entry: a, target: a }));
        return windows.concat(apps);
    }

    function normalizedDesktopId(value) {
        return (value ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function desktopEntryFor(toplevel) {
        const appId = toplevel?.appId ?? "";
        if (!appId) return null;
        const exact = DesktopEntries.heuristicLookup(appId);
        if (exact) return exact;
        const wanted = normalizedDesktopId(appId);
        if (!wanted) return null;
        var entries = DesktopEntries.applications?.values ?? [];
        for (var j = 0; j < entries.length; j++) {
            var entry = entries[j];
            if (searchModel.normalizedDesktopId(entry.id) === wanted
                || searchModel.normalizedDesktopId(entry.startupClass) === wanted)
                return entry;
        }
        return null;
    }

    function desktopIconSource(entry) {
        var icon = entry?.icon ?? "";
        if (!icon) return "";
        return icon.startsWith("/") ? "file://" + icon : "image://icon/" + icon;
    }

    function activate(index, forceTerminal = false) {
        const result = results[index];
        if (!result) return false;
        if (result.kind === "WINDOW") result.target.activate();
        else if (forceTerminal || result.target.runInTerminal) {
            const entry = result.target;
            if (!entry.command.length || !terminalCommand.length) return false;
            Quickshell.execDetached({
                command: [...terminalCommand, ...entry.command],
                workingDirectory: entry.workingDirectory
            });
        } else result.target.execute();
        return true;
    }
}
