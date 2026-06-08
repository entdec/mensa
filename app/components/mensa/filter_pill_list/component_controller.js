import ApplicationController from "mensa/controllers/application_controller";
import { get } from "@rails/request.js";

export default class FilterPillListComponentController extends ApplicationController {
    static outlets = ["mensa-table", "mensa-filter-pill", "mensa-add-filter"];
    static targets = ["searchInput", "resetSearchButton"];

    static values = {
        supportsViews: Boolean,
        tableName: String,
    };

    connect() {
        super.connect();
        this._monitorResetButton();
    }

    // The mensa-table outlet provides `ourUrl`, which we need both to apply and
    // to restore state. Outlets connect asynchronously, so we trigger the restore
    // from the outlet-connected callback to be sure it's available.
    mensaTableOutletConnected() {
        this.restoreState();
    }

    // --- Search actions (formerly in search component controller) ---

    searchFocused(event) {
        if (this.hasMensaAddFilterOutlet) {
            // Don't open the column list while the value popover is already showing —
            // focusing the search input for keyboard nav must not clobber the popover.
            if (this.mensaAddFilterOutlet.isValuePopoverOpen) return;
            this.mensaAddFilterOutlet.filterColumns("");
            this.mensaAddFilterOutlet.showList(this.searchInputTarget);
        }
    }

    monitorSearch(event) {
        const value = this.hasSearchInputTarget ? this.searchInputTarget.value : "";
        this._monitorResetButton();

        if (this.hasMensaAddFilterOutlet) {
            if (this.mensaAddFilterOutlet.isValuePopoverOpen) return;
            this.mensaAddFilterOutlet.filterColumns(value);
            if (value.length > 0) {
                if (this.mensaAddFilterOutlet.visibleColumnCount > 0) {
                    this.mensaAddFilterOutlet.showList(this.searchInputTarget);
                } else {
                    // No matching columns — hide column list so Enter does a text search
                    this.mensaAddFilterOutlet.hideList();
                }
            } else {
                this.mensaAddFilterOutlet.showList(this.searchInputTarget);
            }
        }
    }

    resetSearch(event) {
        if (event) event.preventDefault();

        if (this.hasSearchInputTarget) {
            this.searchInputTarget.value = "";
            this.searchInputTarget.focus();
        }
        if (this.hasResetSearchButtonTarget) {
            this.resetSearchButtonTarget.classList.add("hidden");
        }
        if (this.hasMensaAddFilterOutlet) {
            this.mensaAddFilterOutlet.hideList();
            this.mensaAddFilterOutlet.closeValuePopover?.();
        }

        this.setQuery("");
    }

    search(event) {
        event.preventDefault();

        // If the value popover is open, Enter confirms the highlighted/selected item
        if (this.hasMensaAddFilterOutlet && this.mensaAddFilterOutlet.isValuePopoverOpen) {
            this.mensaAddFilterOutlet.confirmHighlightedValue();
            return;
        }

        // If the column autocomplete has visible options and one is selected via
        // keyboard, let the add-filter controller handle it
        if (this.hasMensaAddFilterOutlet && this.mensaAddFilterOutlet.hasHighlightedColumn) {
            this.mensaAddFilterOutlet.confirmHighlightedColumn();
            return;
        }

        // Hide column dropdown before searching
        if (this.hasMensaAddFilterOutlet) {
            this.mensaAddFilterOutlet.hideList();
        }

        const query = this.hasSearchInputTarget ? this.searchInputTarget.value : "";
        if (query.length > 0 && query.length < 3) return;

        this.setQuery(query);
    }

    navigateDown(event) {
        event.preventDefault();
        if (!this.hasMensaAddFilterOutlet) return;
        if (this.mensaAddFilterOutlet.isValuePopoverOpen) {
            this.mensaAddFilterOutlet.highlightNextValue();
        } else {
            this.mensaAddFilterOutlet.highlightNext();
        }
    }

    navigateUp(event) {
        event.preventDefault();
        if (!this.hasMensaAddFilterOutlet) return;
        if (this.mensaAddFilterOutlet.isValuePopoverOpen) {
            this.mensaAddFilterOutlet.highlightPrevValue();
        } else {
            this.mensaAddFilterOutlet.highlightPrev();
        }
    }

    // --- Filter state management ---

    // Called when an existing filter pill is clicked.
    editFilter(columnName, value, operator, anchor) {
        if (!this.hasMensaAddFilterOutlet) return;
        this.mensaAddFilterOutlet.editColumn(columnName, value, operator, anchor);
    }

    // Called when a filter is added/changed.
    refreshFilters() {
        this._notifyUnsavedState();
        return this.applyState({
            filters: this.collectFilters(),
            query: this.loadQuery(),
            view: this.loadView(),
            order: this.loadOrder(),
            page: "",
        });
    }

// Called by the search controller when the query is submitted or reset.
    setQuery(query) {
        if (query && query.length > 0) this._notifyUnsavedState();
        this.applyState({
            filters: this.collectFilters(),
            query,
            view: this.loadView(),
            order: this.loadOrder(),
            page: "",
        });
    }

    // Called by the views controller when a view tab is selected.
    viewSelected(view) {
        const state = {
            filters: {},
            query: "",
            view,
            order: this.loadOrder(),
            page: "",
        };
        this.persistState(state);
        this.setSearchField("");
        this.updateSearchPlaceholder();
        if (this.hasMensaTableOutlet) {
            this.mensaTableOutlet.viewChanged();
        }
        this.requestState(state);
    }

    // Called by the table controller after a turbo-frame navigation.
    captureNavigation(src) {
        let url;
        try {
            url = new URL(src, window.location.origin);
        } catch (e) {
            return;
        }

        this.lastTableUrl = url.toString();
        this.persistPage(url.searchParams.get("page") || "");
        this.persistView(url.searchParams.get("table_view_id") || "");
        const order = this.parseOrderParams(url.searchParams);
        this.persistOrder(order);

        if (Object.keys(order).length > 0) {
            this._notifyUnsavedState();
        }
    }

    currentRequestState() {
        let url;
        try {
            url = this.lastTableUrl
                ? new URL(this.lastTableUrl, window.location.origin)
                : this.mensaTableOutlet.ourUrl;
        } catch (e) {
            url = this.mensaTableOutlet.ourUrl;
        }

        const params = url.searchParams;
        const filters = {};
        const order = {};
        params.forEach((value, key) => {
            // Multi-select: filters[col][value][]
            const multiMatch = key.match(/^filters\[(.+?)\]\[value\]\[\]$/);
            if (multiMatch) {
                const column = multiMatch[1];
                const f = (filters[column] = filters[column] || {});
                f.value = Array.isArray(f.value) ? [...f.value, value] : [value];
                return;
            }
            const filterMatch = key.match(/^filters\[(.+?)\]\[(value|operator)\]$/);
            if (filterMatch) {
                const column = filterMatch[1];
                (filters[column] = filters[column] || {})[filterMatch[2]] = value;
                return;
            }
            const orderMatch = key.match(/^order\[(.+)\]$/);
            if (orderMatch) order[orderMatch[1]] = value;
        });

        return {
            filters,
            query: params.get("query") || "",
            view: params.get("table_view_id") || "",
            page: params.get("page") || "",
            order,
        };
    }

    clearFiltersAndSearch() {
        const view = this.loadView();
        // Wipe all dirty-state entries; keep only the active view.
        this.clearPersistedDirtyState();
        this.persistView(view);
        this.setSearchField("");
        // buildUrl reads column_order/hidden_columns from localStorage — now empty,
        // so the server receives a completely clean request for the current view.
        this.requestState({ filters: {}, query: "", view, order: {}, page: "" });
    }

    restoreState() {
        const table = this.mensaTableOutlet;
        const filters = this.loadFilters();
        const query = this.loadQuery();
        const view = this.loadView();
        const page = this.loadPage();
        const order = this.loadOrder();
        const columnOrder = this.loadColumnOrder();
        const hiddenColumns = this.loadHiddenColumns();

        // Show save/reset if any persistent state exists (order, column layout, filters, search)
        if (
            Object.keys(filters).length > 0 ||
            query.length > 0 ||
            Object.keys(order).length > 0 ||
            columnOrder.length > 0 ||
            hiddenColumns.length > 0
        ) {
            this._notifyUnsavedState();
        }

        const hasFilterOrSearch =
            Object.keys(filters).length > 0 || query.length > 0;
        const hasState =
            hasFilterOrSearch ||
            view.length > 0 ||
            page.length > 0 ||
            Object.keys(order).length > 0 ||
            columnOrder.length > 0;

        const alreadyRendered = Object.keys(this.renderedFilters()).length > 0;

        if (!hasState || alreadyRendered || table.frameLoadHandled) {
            if (typeof table.loadFrame === "function") {
                table.loadFrame();
            }
            return;
        }

        table.frameLoadHandled = true;

        this.setSearchField(query);
        this.setViewHighlight(view);

        const state = { filters, query, view, page, order };

        // No need to show/hide the filter bar — it's always visible.
        // Just apply state and load the frame.
        this.applyState(state);
    }

    applyState(state) {
        return this.persistAndRequest(state);
    }

    persistAndRequest(state) {
        this.persistState(state);
        return this.requestState(state);
    }

    requestState(state) {
        const url = this.buildUrl(state);
        this.lastTableUrl = url.toString();
        return get(url, { responseKind: "turbo-stream" });
    }

    buildUrl(state) {
        const url = this.mensaTableOutlet.ourUrl;

        this.removeFilterParams(url);
        this.removeOrderParams(url);
        this.removeColumnParams(url);
        url.searchParams.delete("query");
        url.searchParams.delete("page");
        url.searchParams.delete("table_view_id");

        Object.entries(state.filters || {}).forEach(([columnName, filter]) => {
            if (Array.isArray(filter.value)) {
                filter.value.forEach((v) =>
                    url.searchParams.append(`filters[${columnName}][value][]`, v),
                );
            } else {
                url.searchParams.append(`filters[${columnName}][value]`, filter.value ?? "");
            }
            url.searchParams.append(`filters[${columnName}][operator]`, filter.operator);
        });

        Object.entries(state.order || {}).forEach(([columnName, direction]) => {
            url.searchParams.set(`order[${columnName}]`, direction);
        });

        if (state.query) url.searchParams.set("query", state.query);
        if (state.view) url.searchParams.set("table_view_id", state.view);
        if (state.page) url.searchParams.set("page", state.page);

        this.loadColumnOrder().forEach((col) =>
            url.searchParams.append("column_order[]", col),
        );
        this.loadHiddenColumns().forEach((col) =>
            url.searchParams.append("hidden_columns[]", col),
        );

        return url;
    }

    removeFilterParams(url) {
        const keys = new Set();
        url.searchParams.forEach((_v, key) => {
            if (key.startsWith("filters[")) keys.add(key);
        });
        keys.forEach((key) => url.searchParams.delete(key));
    }

    removeColumnParams(url) {
        const keys = [];
        url.searchParams.forEach((_v, key) => {
            if (key.startsWith("column_order") || key.startsWith("hidden_columns")) keys.push(key);
        });
        keys.forEach((key) => url.searchParams.delete(key));
    }

    removeOrderParams(url) {
        const keys = [];
        url.searchParams.forEach((_v, key) => {
            if (key.startsWith("order[")) keys.push(key);
        });
        keys.forEach((key) => url.searchParams.delete(key));
    }

    parseOrderParams(searchParams) {
        const order = {};
        searchParams.forEach((value, key) => {
            const match = key.match(/^order\[(.+)\]$/);
            if (match) order[match[1]] = value;
        });
        return order;
    }

    collectFilters() {
        const filters = this.renderedFilters();

        if (this.hasMensaAddFilterOutlet && this.mensaAddFilterOutlet.selectedFilterColumn) {
            const isMultiple = this.mensaAddFilterOutlet.isMultipleMode;
            const value = isMultiple
                ? this.mensaAddFilterOutlet.selectedValues
                : this.mensaAddFilterOutlet.hasValueTarget
                    ? this.mensaAddFilterOutlet.valueTarget.value
                    : "";
            filters[this.mensaAddFilterOutlet.selectedFilterColumn] = {
                value,
                operator: this.mensaAddFilterOutlet.operator,
            };
        }

        return filters;
    }

    renderedFilters() {
        const filters = {};

        this.element
            .querySelectorAll('[data-controller~="mensa-filter-pill"]')
            .forEach((pill) => {
                const columnName = pill.getAttribute("data-mensa-filter-pill-column-name-value");
                if (!columnName) return;

                const rawValue = pill.getAttribute("data-mensa-filter-pill-value-value");
                let value;
                try { value = JSON.parse(rawValue); } catch { value = rawValue; }

                filters[columnName] = {
                    value,
                    operator: pill.getAttribute("data-mensa-filter-pill-operator-value"),
                };
            });

        return filters;
    }

    setSearchField(query) {
        if (this.hasSearchInputTarget) {
            this.searchInputTarget.value = query || "";
        }
        this._monitorResetButton();
    }

    setViewHighlight(view) {
        if (!view) return;

        const root = this.element.closest(".mensa-table");
        if (!root) return;

        // Update the views dropdown option checks
        root.querySelectorAll('[data-mensa-views-target="view"]').forEach((el) => {
            const linkView = el.getAttribute("data-view-id") || "";
            const check = el.querySelector(".mensa-table__views__option-check");
            if (check) {
                check.classList.toggle("invisible", view !== "" && linkView !== view);
            }
        });

        // Update the trigger label
        const triggerLabel = root.querySelector('[data-mensa-views-target="triggerLabel"]');
        if (triggerLabel && view) {
            const viewEl = root.querySelector(`[data-mensa-views-target="view"][data-view-id="${view}"]`);
            if (viewEl) {
                const name = viewEl.dataset.viewName || viewEl.querySelector("span")?.textContent?.trim();
                if (name) triggerLabel.textContent = name;
            }
        }

        this.updateSearchPlaceholder();
    }

    updateSearchPlaceholder() {
        // Placeholder is always "Search and filter" — no dynamic update needed.
    }

    // Clears all dirty-state localStorage keys so the view is clean after save.
    clearPersistedDirtyState() {
        this.writeStorage(this.filtersStorageKey, null);
        this.writeStorage(this.searchStorageKey, null);
        this.writeStorage(this.orderStorageKey, null);
        this.writeStorage(`mensa:column_order:${this.tableNameValue}`, null);
        this.writeStorage(`mensa:hidden_columns:${this.tableNameValue}`, null);
    }

    // Keep these for backward-compatibility with other controllers that look up
    // the search input via helper methods.
    searchInputElement() {
        return this.hasSearchInputTarget ? this.searchInputTarget : null;
    }

    resetSearchButtonElement() {
        return this.hasResetSearchButtonTarget ? this.resetSearchButtonTarget : null;
    }

    // --- Persistence ---

    persistState(state) {
        this.persistFilters(state.filters || {});
        this.persistQuery(state.query || "");
        this.persistView(state.view || "");
        this.persistPage(state.page || "");
        this.persistOrder(state.order || {});
    }

    persistFilters(filters) {
        this.writeStorage(
            this.filtersStorageKey,
            Object.keys(filters).length > 0 ? JSON.stringify(filters) : null,
        );
    }

    loadFilters() {
        const raw = this.readStorage(this.filtersStorageKey);
        if (!raw) return {};
        try {
            return JSON.parse(raw);
        } catch (e) {
            return {};
        }
    }

    persistQuery(query) {
        this.writeStorage(this.searchStorageKey, query && query.length > 0 ? query : null);
    }

    loadQuery() {
        return this.readStorage(this.searchStorageKey) || "";
    }

    persistView(view) {
        this.writeStorage(this.viewStorageKey, view && view.length > 0 ? view : null);
    }

    loadView() {
        return this.readStorage(this.viewStorageKey) || "";
    }

    persistPage(page) {
        this.writeStorage(this.pageStorageKey, page && page !== "1" ? page : null);
    }

    loadPage() {
        return this.readStorage(this.pageStorageKey) || "";
    }

    persistOrder(order) {
        this.writeStorage(
            this.orderStorageKey,
            order && Object.keys(order).length > 0 ? JSON.stringify(order) : null,
        );
    }

    loadOrder() {
        const raw = this.readStorage(this.orderStorageKey);
        if (!raw) return {};
        try {
            return JSON.parse(raw);
        } catch (e) {
            return {};
        }
    }

    writeStorage(key, value) {
        if (!this.hasStorage) return;
        try {
            if (value === null) {
                window.localStorage.removeItem(key);
            } else {
                window.localStorage.setItem(key, value);
            }
        } catch (e) {}
    }

    readStorage(key) {
        if (!this.hasStorage) return null;
        try {
            return window.localStorage.getItem(key);
        } catch (e) {
            return null;
        }
    }

    get hasStorage() {
        try {
            return typeof window !== "undefined" && !!window.localStorage;
        } catch (e) {
            return false;
        }
    }

    loadColumnOrder() {
        try {
            return JSON.parse(this.readStorage(`mensa:column_order:${this.tableNameValue}`)) || [];
        } catch (e) {
            return [];
        }
    }

    loadHiddenColumns() {
        try {
            return JSON.parse(this.readStorage(`mensa:hidden_columns:${this.tableNameValue}`)) || [];
        } catch (e) {
            return [];
        }
    }

    get filtersStorageKey() { return `mensa:filters:${this.tableNameValue}`; }
    get searchStorageKey() { return `mensa:search:${this.tableNameValue}`; }
    get viewStorageKey() { return `mensa:view:${this.tableNameValue}`; }
    get pageStorageKey() { return `mensa:page:${this.tableNameValue}`; }
    get orderStorageKey() { return `mensa:order:${this.tableNameValue}`; }

    get ourUrl() {
        return this.mensaTableOutlet.ourUrl;
    }

    // --- Private ---

    _monitorResetButton() {
        if (!this.hasSearchInputTarget) return;
        const hasValue = this.searchInputTarget.value.length > 0;
        if (this.hasResetSearchButtonTarget) {
            this.resetSearchButtonTarget.classList.toggle("hidden", !hasValue);
        }
    }

    _notifyUnsavedState() {
        if (this.hasMensaTableOutlet && typeof this.mensaTableOutlet.notifyUnsavedState === "function") {
            this.mensaTableOutlet.notifyUnsavedState();
        }
    }
}
