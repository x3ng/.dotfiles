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
        const q = query.trim().toLocaleLowerCase();
        const terms = q ? q.split(/\s+/).filter(t => t) : [];
        const matches = text => terms.every(t => text.toLocaleLowerCase().includes(t));
        // Match tiers, best to worst: a prefix (0), a word start (1), any
        // substring (2), no match (3). Word start means the match sits after a
        // space, dot, dash or underscore ("files" in "gnome-files").
        const PREFIX = 0, WORD = 1, SUBSTRING = 2, NONE = 3;
        const oneScore = (t, needle) => {
            const i = t.indexOf(needle);
            if (i === 0) return PREFIX;
            if (i > 0 && /[\s\-_./]/.test(t[i - 1])) return WORD;
            return i > 0 ? SUBSTRING : NONE;
        };
        const score = text => {
            if (!q) return WORD;
            const t = text.toLocaleLowerCase();
            if (t.includes(q)) return oneScore(t, q);
            // Multi-word query: rank by the best-matching word.
            return Math.min(...terms.map(term => oneScore(t, term)));
        };
        const windows = ToplevelManager.toplevels.values.map((w, i) => ({
            kind: "WINDOW", title: w.title || w.appId, detail: w.appId,
            entry: desktopEntryFor(w), target: w, order: i
        })).filter(r => matches(r.title + " " + r.detail))
            .map(r => {
                // The title decides a window's rank. When only the app id
                // matches it is demoted one tier, so it never outranks a name
                // match but still outranks an unmatched window; the final
                // sort then prefers windows on ties.
                const titleScore = score(r.title);
                const appIdScore = score(r.detail);
                r.score = titleScore < NONE
                    ? titleScore : Math.min(NONE, appIdScore + 1);
                return r;
            });
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay
            && matches(a.name + " " + a.genericName + " " + a.comment + " " + a.id))
            .map(a => {
                // The name decides an app's rank; a hit in only the comment or
                // desktop id is demoted one tier, so a descriptive match such
                // as "browser" cannot outrank a real name match.
                const nameScore = Math.min(score(a.name), score(a.genericName || a.name));
                const metaScore = Math.min(score(a.comment || ""), score(a.id));
                return { kind: "APP", title: a.name,
                    detail: a.genericName || a.comment || a.id,
                    entry: a, target: a,
                    score: Math.min(nameScore, Math.min(NONE, metaScore + 1)) };
            })
            .sort((a, b) => a.title.localeCompare(b.title))
            .map((a, i) => { a.order = i; return a; });
        // Strongest match first; windows win ties so Enter keeps focusing the
        // existing window instead of launching a duplicate.
        return windows.concat(apps).sort((a, b) => a.score - b.score
            || (a.kind === b.kind ? a.order - b.order
                : a.kind === "WINDOW" ? -1 : 1));
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
