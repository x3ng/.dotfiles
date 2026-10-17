// Run: node --test quickshell/tests/search-navigation.test.cjs
// Execute the production QML JavaScript with inert services, never a desktop.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
const searchSource = source('DesktopSearch.qml');
const panelSource = source('components/LauncherPanel.qml');
function functions(text, names) {
    return names.map(name => {
        const start = text.indexOf(`    function ${name}(`);
        assert.notEqual(start, -1, `missing production function ${name}`);
        const body = text.indexOf('{', start);
        let depth = 1, end = body + 1;
        // These functions have no braces embedded in strings or regex literals.
        for (; depth && end < text.length; end++) {
            if (text[end] === '{') depth++;
            if (text[end] === '}') depth--;
        }
        return text.slice(start, end);
    }).join('\n');
}
function searchContext() {
    const calls = [];
    const context = {
        query: '', actions: {entries: [], execute: id => { calls.push(id); return true; }},
        ToplevelManager: {toplevels: {values: []}},
        DesktopEntries: {applications: {values: []}},
        desktopEntryFor: () => null,
        launchApplication: () => true,
        calls
    };
    const marker = 'readonly property var results: ';
    const start = searchSource.indexOf(marker) + marker.length;
    const end = searchSource.indexOf('\n\n    function normalizedDesktopId');
    vm.createContext(context);
    vm.runInContext('function calculate() ' + searchSource.slice(start, end)
        + '\n' + functions(searchSource, ['activate', 'activateResult']), context);
    return context;
}
function panelContext() {
    const later = [];
    const context = {
        open: false, homeTab: 'desktop', controlSection: '', query: '',
        selectedIndex: 0, selectedKey: null, selectionQuery: '', selectionRevision: 0, results: [],
        homeTabDefinitions: [{key: 'desktop'}, {key: 'controls'}],
        detailSections: ['wifi', 'bluetooth', 'audio', 'notifications'],
        panelState: {ready: true, lastHomeTab: 'desktop',
            setLastHomeTab(tab) { this.lastHomeTab = tab; }},
        search: {focuses: 0, inputMethodComposing: false,
            forceActiveFocus() { this.focuses++; }},
        controlDetails: {focuses: 0, forceActiveFocus() { this.focuses++; }},
        searchResultsPage: {showSelection() {}, resetScroll() {}},
        trayMenu: {dismiss() {}}, searchModel: {activateResult: () => ({accepted: false, closePanel: false})},
        Qt: {callLater: fn => later.push(fn), ControlModifier: 1, AltModifier: 2,
            MetaModifier: 4, ShiftModifier: 8, Key_Tab: 9, Key_Backtab: 10,
            Key_0: 48, Key_9: 57, Key_N: 78, Key_P: 80, Key_G: 71},
        flush() { while (later.length) later.shift()(); }
    };
    context.panel = context;
    Object.defineProperty(context, 'searching', {get: () => !!context.query.trim()});
    Object.defineProperty(context, 'showingDetails', {get: () => !!context.controlSection});
    vm.createContext(context);
    vm.runInContext(functions(panelSource, ['syncSelection', 'resetSelection', 'moveSelection', 'activate',
        'openOnScreen', 'dismiss', 'selectHome', 'returnToHome', 'showDetails', 'handleEscape', 'handleKey']), context);
    return context;
}

test('live title changes retain selection by action ID, not row position', () => {
    const search = searchContext(), panel = panelContext();
    panel.open = true;
    let visibleSelection = -1;
    panel.searchResultsPage.showSelection = index => { visibleSelection = index; };
    search.query = panel.query = 'mute';
    search.actions.entries = [{id: 'output', title: 'Mute output'}, {id: 'mic', title: 'Mute microphone'}];
    panel.results = search.calculate();
    panel.syncSelection();
    panel.moveSelection(1);
    assert.equal(panel.selectedKey, 'action:mic');
    search.actions.entries[0].title = 'Unmute output';
    panel.results = search.calculate();
    panel.syncSelection();
    assert.equal(panel.selectedIndex, 0);
    assert.equal(panel.results[panel.selectedIndex].target.id, 'mic');
    panel.flush();
    assert.equal(visibleSelection, panel.selectedIndex);
    panel.results = panel.results.filter(row => row.target.id !== 'mic');
    panel.syncSelection();
    assert.equal(panel.selectedKey, 'action:output');
    panel.results = [];
    panel.syncSelection();
    assert.equal(panel.selectedKey, null);
    assert.equal(panel.selectedIndex, 0);
});

test('query changes reset selection regardless of binding notification order', () => {
    for (const resultsFirst of [false, true]) {
        const panel = panelContext();
        panel.query = 'old'; panel.results = [{key: 'a'}, {key: 'b'}];
        panel.syncSelection(); panel.moveSelection(1);
        panel.query = 'new';
        if (resultsFirst) { panel.results = [{key: 'b'}, {key: 'a'}]; panel.syncSelection(); }
        panel.resetSelection();
        if (!resultsFirst) { panel.results = [{key: 'b'}, {key: 'a'}]; panel.syncSelection(); }
        panel.flush();
        assert.equal(panel.selectedIndex, 0);
        assert.equal(panel.selectedKey, 'b');
    }
});

test('deferred query reset does not undo a newer explicit result selection', () => {
    const panel = panelContext();
    panel.query = 'mute';
    panel.results = [{key: 'output'}, {key: 'mic'}];
    panel.resetSelection();
    panel.moveSelection(1);
    panel.flush();
    assert.equal(panel.selectedIndex, 1);
    assert.equal(panel.selectedKey, 'mic');
});

test('invalid detail routes leave page, query and focus untouched', () => {
    const panel = panelContext();
    panel.open = true;
    panel.query = 'test';
    assert.equal(panel.showDetails('unknown'), false);
    assert.equal(panel.showDetails(null), false);
    panel.flush();
    assert.equal(panel.query, 'test');
    assert.equal(panel.homeTab, 'desktop');
    assert.equal(panel.controlSection, '');
    assert.equal(panel.controlDetails.focuses, 0);
    assert.equal(panel.panelState.lastHomeTab, 'desktop');
});

test('reopening restores only the remembered home tab, never search or details', () => {
    const panel = panelContext();
    panel.openOnScreen({name: 'first'});
    panel.selectHome('controls');
    panel.query = 'private search';
    panel.dismiss();
    panel.openOnScreen({name: 'second'});
    assert.equal(panel.homeTab, 'controls');
    assert.equal(panel.query, '');
    assert.equal(panel.controlSection, '');
    panel.selectHome('desktop');
    panel.showDetails('audio');
    assert.equal(panel.panelState.lastHomeTab, 'controls');
    panel.dismiss();
    panel.openOnScreen({name: 'third'});
    assert.equal(panel.homeTab, 'controls');
    assert.equal(panel.controlSection, '');
    assert.equal(panel.query, '');
    assert.equal(panel.screen.name, 'third');
});

test('late panel state loading affects the next open, not the current page', () => {
    const panel = panelContext();
    panel.panelState.ready = false;
    panel.openOnScreen({name: 'mock'});
    panel.panelState.lastHomeTab = 'controls';
    panel.panelState.ready = true;
    assert.equal(panel.homeTab, 'desktop');
    panel.dismiss();
    panel.openOnScreen({name: 'mock'});
    assert.equal(panel.homeTab, 'controls');
    panel.dismiss();
    panel.panelState.lastHomeTab = 'invalid';
    panel.openOnScreen({name: 'mock'});
    assert.equal(panel.homeTab, 'desktop');
});

test('stable source ordering, bilingual keywords and live window identity', () => {
    const search = searchContext();
    const window = {title: 'Power window', appId: 'power'};
    search.ToplevelManager.toplevels.values = [window];
    search.DesktopEntries.applications.values = [{name: 'Power app', id: 'power', genericName: '', comment: ''}];
    search.actions.entries = [
        {id: 'one', title: 'Power action', keywords: '电源 能源'},
        {id: 'two', title: 'Power second', keywords: ['电源', '性能']}
    ];
    search.query = 'power';
    let rows = search.calculate();
    assert.deepEqual(Array.from(rows, row => row.kind), ['WINDOW', 'APP', 'ACTION', 'ACTION']);
    assert.equal(rows[0].key, window);
    window.title = 'Power renamed';
    assert.equal(search.calculate()[0].key, window);
    search.query = '电源 性能';
    rows = search.calculate();
    assert.deepEqual(Array.from(rows, row => row.key), ['action:two']);
});

test('activation distinguishes accepted request from closing the panel', () => {
    const search = searchContext();
    const action = {kind: 'ACTION', target: {id: 'wifi'}};
    assert.equal(search.activateResult(action).accepted, true);
    assert.equal(search.activateResult(action).closePanel, false);
    search.actions.execute = () => false;
    assert.equal(search.activateResult(action).accepted, false);
    assert.equal(search.activateResult({...action, enabled: false}).accepted, false);
    const window = {activate: () => search.calls.push('window')};
    assert.equal(search.activateResult({kind: 'WINDOW', target: window}).accepted, false);
    search.ToplevelManager.toplevels.values = [window];
    const focused = search.activateResult({kind: 'WINDOW', target: window});
    assert.equal(focused.accepted, true); assert.equal(focused.closePanel, true);
    search.launchApplication = () => false;
    assert.equal(search.activateResult({kind: 'APP', target: {}}).closePanel, false);
    assert.equal(search.activateResult({kind: 'UNKNOWN'}).accepted, false);
});

test('action captures row before query reorder; rejection restores the query', () => {
    const panel = panelContext();
    panel.open = true;
    panel.results = [{key: 'action:wifi', kind: 'ACTION', target: {id: 'wifi'}}];
    let query = 'network';
    Object.defineProperty(panel, 'query', {get: () => query, set: value => { query = value; panel.results = []; }});
    panel.searchModel.activateResult = row => {
        assert.equal(panel.query, ''); assert.equal(row.target.id, 'wifi');
        return {accepted: false, closePanel: false};
    };
    panel.activate(0);
    assert.equal(panel.query, 'network'); assert.equal(panel.open, true);
});

test('Esc, tabs, shortcuts and delayed focus preserve navigation semantics', () => {
    const panel = panelContext();
    panel.openOnScreen({name: 'mock'});
    panel.selectHome('controls'); panel.query = 'network'; panel.handleEscape();
    assert.equal(panel.homeTab, 'controls'); assert.equal(panel.query, '');
    panel.showDetails('wifi'); panel.handleEscape();
    assert.equal(panel.controlSection, ''); assert.equal(panel.homeTab, 'controls');
    panel.handleKey({key: panel.Qt.Key_Tab, modifiers: 0});
    assert.equal(panel.homeTab, 'desktop');
    panel.selectHome('invalid'); assert.equal(panel.homeTab, 'desktop');
    panel.query = 'test'; panel.results = Array.from({length: 10}, (_, i) => ({key: String(i), kind: 'APP'}));
    panel.syncSelection();
    panel.handleKey({key: panel.Qt.Key_N, modifiers: 1}); assert.equal(panel.selectedIndex, 1);
    panel.handleKey({key: panel.Qt.Key_P, modifiers: 1}); assert.equal(panel.selectedIndex, 0);
    let activated;
    panel.searchModel.activateResult = row => { activated = row.key; return {accepted: true, closePanel: true}; };
    panel.handleKey({key: panel.Qt.Key_0, modifiers: 1});
    assert.equal(activated, '9'); assert.equal(panel.open, false);
    panel.flush();
    assert.equal(panel.search.focuses, 0); assert.equal(panel.controlDetails.focuses, 0);
});
