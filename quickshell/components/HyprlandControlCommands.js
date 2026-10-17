// Only validated numeric IDs and hexadecimal addresses enter Lua source.
// Titles, classes and workspace names are display data, never executable text.
function address(value) {
    if (typeof value !== "string") return "";
    const raw = value.toLowerCase().replace(/^0x/, "");
    return /^[0-9a-f]{1,16}$/.test(raw) && !/^0+$/.test(raw) ? "0x" + raw : "";
}
function validId(value) { return Number.isInteger(value) && value !== 0 && Math.abs(value) <= 2147483647; }
function workspaceGuard(row, allowEmpty) {
    if (!row || !validId(row.id)) return null;
    if (!row.exists) {
        if (!allowEmpty || row.id < 1 || row.id > 10) return null;
        return "local target = " + row.id + "; ";
    }
    // Enumerate exact IDs, including named and special workspaces, without parsing selectors.
    return "local target; for _, ws in ipairs(hl.get_workspaces()) do if ws.id == " + row.id
        + " then target = ws; break end end; if not target then return 'ERROR: Workspace no longer exists' end; ";
}
function result(dispatcher) {
    return "local result = hl.dispatch(" + dispatcher + "); "
        + "if not result or not result.ok then return 'ERROR: ' .. tostring(result and result.error or 'Operation failed') end; return 'OK'";
}
function windowAction(action, windowRow, workspaceRow) {
    const target = address(windowRow?.address);
    if (!target) return {error: "Window no longer exists"};
    let prefix = "local win = hl.get_window('address:" + target
        + "'); if not win or not win.mapped then return 'ERROR: Window no longer exists' end; ";
    let dispatch;
    if (action === "focus") dispatch = "hl.dsp.focus({window = win})";
    else if (action === "float") dispatch = "hl.dsp.window.float({window = win, action = 'toggle'})";
    else if (action === "fullscreen") dispatch = "hl.dsp.window.fullscreen({window = win, mode = 'fullscreen', action = 'toggle'})";
    else if (action === "close") dispatch = "hl.dsp.window.close({window = win})";
    else if (action === "move") {
        const guard = workspaceGuard(workspaceRow, true);
        if (!guard) return {error: "Workspace no longer exists"};
        prefix += guard;
        dispatch = "hl.dsp.window.move({window = win, workspace = target, follow = false})";
    } else return {error: "Unknown window operation"};
    return {code: prefix + result(dispatch)};
}
function workspaceAction(action, workspaceRow, layout) {
    const guard = workspaceGuard(workspaceRow, action === "focus");
    if (!guard) return {error: "Enter this workspace before changing its layout"};
    if (action === "focus") return {code: guard + result("hl.dsp.focus({workspace = target})")};
    if (action !== "layout" || !["dwindle", "master", "scrolling", "monocle"].includes(layout))
        return {error: "Unknown workspace layout"};
    return {code: guard + "hl.workspace_rule({workspace = target.config_name, layout = '" + layout + "'}); "
        + "hl.dispatch(hl.dsp.event('workspace-layout')); return 'OK'"};
}
