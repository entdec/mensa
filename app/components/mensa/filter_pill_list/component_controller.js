import ApplicationController from "mensa/controllers/application_controller";
import { get } from "@rails/request.js";

export default class FilterPillListComponentController extends ApplicationController {
    static outlets = ["mensa-table", "mensa-filter-pill", "mensa-add-filter"];

    static targets = [];

    static values = {
        supportsViews: Boolean,
        tableName: String,
    };

    connect() {
        super.connect();
    }

    // The mensa-table outlet provides `ourUrl`, which we need both to apply and
    // to restore state. Outlets connect asynchronously, so we trigger the restore
    // from the outlet-connected callback to be sure it's available.
    mensaTableOutletConnected() {
        this.restoreState();
    }

    // Called when an existing filter pill is clicked. Delegates to the add-filter
    // controller so the value popover re-opens for that column, pre-selected to
    // the current value; picking a new value flows back through refreshFilters().
    editFilter(columnName, value, anchor) {
        if (!this.hasMensaAddFilterOutlet) return;

        this.mensaAddFilterOutlet.editColumn(columnName, value, anchor);
    }

    // Called when a filter is added/changed. Persists the resulting state and
    // re-requests the table (keeping the active search and view, resetting paging).
    refreshFilters() {
        this.applyState({
            filters: this.collectFilters(),
            query: this.loadQuery(),
            view: this.loadView(),
            order: this.loadOrder(),
            page: "",
        });
    }

    // Called by the search controller when the query is submitted or reset. Keeps
    // any active filters and view in place while updating the query.
    setQuery(query) {
        this.applyState({
            filters: this.collectFilters(),
            query,
            view: this.loadView(),
            order: this.loadOrder(),
            page: "",
        });
    }

    // Called by the views controller when a view tab is selected. Selecting a view
    // resets filters, search and paging (the view link itself reloads the data via
    // the turbo-frame), so here we only persist the new state.
    viewSelected(view) {
        // Selecting a view resets filters, search and paging but keeps the order.
        // We persist that state and immediately fire a turbo-stream request so
        // that both the table view and the filter pill list are updated atomically.
        // The turbo-frame link navigation is suppressed in the views controller so
        // this single request is the only one that runs.
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
        this.requestState(state);
    }

    // Called by the table controller after a turbo-frame navigation (pagination,
    // sorting or a view tab). Only the page, view and sort order can change this
    // way, so we capture them without touching the persisted filters/query.
    captureNavigation(src) {
        let url;
        try {
            url = new URL(src, window.location.origin);
        } catch (e) {
            return;
        }

        // Remember the URL that rendered the table currently on screen so other
        // controllers (e.g. export) can read the exact page/query/order/view the
        // user is looking at.
        this.lastTableUrl = url.toString();

        this.persistPage(url.searchParams.get("page") || "");
        this.persistView(url.searchParams.get("table_view_id") || "");
        this.persistOrder(this.parseOrderParams(url.searchParams));
    }

    // Returns the state of the table currently on screen, read from the URL of
    // the last table request. That URL is authoritative: it is set both when a
    // navigation happens (pagination/sort/view, via captureNavigation) and when
    // filters/search/order change (via requestState), so it always reflects what
    // the user is actually viewing - including the current page and query, which
    // per-key local storage can fail to capture.
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
            const filterMatch = key.match(
                /^filters\[(.+?)\]\[(value|operator)\]$/,
            );
            if (filterMatch) {
                const column = filterMatch[1];
                (filters[column] = filters[column] || {})[filterMatch[2]] =
                    value;
                return;
            }
            const orderMatch = key.match(/^order\[(.+)\]$/);
            if (orderMatch && value) order[orderMatch[1]] = value;
        });

        return {
            filters,
            query: params.get("query") || "",
            view: params.get("table_view_id") || "",
            page: params.get("page") || "",
            order,
        };
    }

    // Removes every applied filter and the search query, forgets them in local
    // storage and clears the search field, then reloads the table (keeping the
    // current view).
    clearFiltersAndSearch() {
        const state = {
            filters: {},
            query: "",
            view: this.loadView(),
            order: this.loadOrder(),
            page: "",
        };

        this.persistState(state);
        this.setSearchField("");
        this.requestState(state);
    }

    // Restores persisted filters, search query, view and page on initial page
    // load.
    //
    // The table controller defers the turbo-frame load so that, when there is
    // persisted state, we can fetch the right table together with its pills in a
    // single request instead of first loading the default frame and then
    // re-requesting. This means a single backend call and no flash of content.
    restoreState() {
        const table = this.mensaTableOutlet;
        const filters = this.loadFilters();
        const query = this.loadQuery();
        const view = this.loadView();
        const page = this.loadPage();
        const order = this.loadOrder();

        const hasFilterOrSearch =
            Object.keys(filters).length > 0 || query.length > 0;
        const hasState =
            hasFilterOrSearch ||
            view.length > 0 ||
            page.length > 0 ||
            Object.keys(order).length > 0;

        // Filters already on screen (e.g. a view's defaults, or a previous restore
        // after this controller was re-rendered) mean there is nothing to restore.
        const alreadyRendered = Object.keys(this.renderedFilters()).length > 0;

        if (!hasState || alreadyRendered || table.frameLoadHandled) {
            // Nothing to restore: trigger the frame's normal load. This is idempotent,
            // so re-renders after a restore (or the table controller's fallback) are a
            // no-op.
            if (typeof table.loadFrame === "function") {
                table.loadFrame();
            }
            return;
        }

        // Claim the deferred frame load so the table controller does not also load
        // the default src.
        table.frameLoadHandled = true;

        this.setSearchField(query);
        this.setViewHighlight(view);

        const state = { filters, query, view, page, order };

        if (hasFilterOrSearch) {
            // Open the filtering chrome so the restored filters/search don't render
            // above the views, then fetch everything in a single request.
            if (typeof table.showFiltersAndSearch === "function") {
                table.showFiltersAndSearch();
            }
            this.applyState(state);
        } else {
            // Only a view and/or page to restore: stay in "views" mode and request.
            this.persistAndRequest(state);
        }
    }

    // Persists the given state and fetches the table, revealing the filter bar
    // once rendered (used for user-driven filter/search changes and restores).
    applyState(state) {
        this.persistAndRequest(state).then(() => {
            // FIXME: There should be a better way to do this, possibly using
            // this.mensaTableOutlet.filterListTarget.addEventListener("turbo:after-stream-render", this.unhide.bind(this)) ?
            setTimeout(() => {
                this.mensaTableOutlet.filterListTarget.classList.remove(
                    "hidden",
                );
            }, 50);
        });
    }

    persistAndRequest(state) {
        this.persistState(state);
        return this.requestState(state);
    }

    // Builds the request URL from the given state and fetches the table via
    // turbo-stream, updating both the filter pills and the table view.
    requestState(state) {
        const url = this.buildUrl(state);
        // Keep the authoritative "what's on screen" URL in sync for filter/search/
        // order changes too (these render via a turbo-stream, not a frame load,
        // so captureNavigation never sees them).
        this.lastTableUrl = url.toString();
        return get(url, {
            responseKind: "turbo-stream",
        });
    }

    buildUrl(state) {
        const url = this.mensaTableOutlet.ourUrl;

        this.removeFilterParams(url);
        this.removeOrderParams(url);
        url.searchParams.delete("query");
        url.searchParams.delete("page");
        url.searchParams.delete("table_view_id");

        Object.entries(state.filters || {}).forEach(([columnName, filter]) => {
            url.searchParams.append(
                `filters[${columnName}][value]`,
                filter.value,
            );
            url.searchParams.append(
                `filters[${columnName}][operator]`,
                filter.operator,
            );
        });

        Object.entries(state.order || {}).forEach(([columnName, direction]) => {
            url.searchParams.set(`order[${columnName}]`, direction);
        });

        if (state.query) url.searchParams.set("query", state.query);
        if (state.view) url.searchParams.set("table_view_id", state.view);
        if (state.page) url.searchParams.set("page", state.page);

        return url;
    }

    // Strips any `filters[...]` query parameters from the given URL in place.
    removeFilterParams(url) {
        const filterKeys = [];
        url.searchParams.forEach((_value, key) => {
            if (key.startsWith("filters[")) {
                filterKeys.push(key);
            }
        });
        filterKeys.forEach((key) => url.searchParams.delete(key));
    }

    // Strips any `order[...]` query parameters from the given URL in place.
    removeOrderParams(url) {
        const orderKeys = [];
        url.searchParams.forEach((_value, key) => {
            if (key.startsWith("order[")) {
                orderKeys.push(key);
            }
        });
        orderKeys.forEach((key) => url.searchParams.delete(key));
    }

    // Parses `order[column]=direction` params into a plain object.
    parseOrderParams(searchParams) {
        const order = {};
        searchParams.forEach((value, key) => {
            const match = key.match(/^order\[(.+)\]$/);
            if (match && value) {
                order[match[1]] = value;
            }
        });
        return order;
    }

    // The full set of active filters: existing pills plus the one currently
    // being added (if any), keyed by column name.
    collectFilters() {
        const filters = this.renderedFilters();

        if (
            this.hasMensaAddFilterOutlet &&
            this.mensaAddFilterOutlet.selectedFilterColumn
        ) {
            filters[this.mensaAddFilterOutlet.selectedFilterColumn] = {
                value: this.mensaAddFilterOutlet.valueTarget.value,
                operator: this.mensaAddFilterOutlet.operator,
            };
        }

        return filters;
    }

    // Filters currently rendered as pills, read straight from the DOM so we
    // don't depend on outlet connection timing.
    renderedFilters() {
        const filters = {};

        this.element
            .querySelectorAll('[data-controller~="mensa-filter-pill"]')
            .forEach((pill) => {
                const columnName = pill.getAttribute(
                    "data-mensa-filter-pill-column-name-value",
                );
                if (!columnName) return;

                filters[columnName] = {
                    value: pill.getAttribute(
                        "data-mensa-filter-pill-value-value",
                    ),
                    operator: pill.getAttribute(
                        "data-mensa-filter-pill-operator-value",
                    ),
                };
            });

        return filters;
    }

    // Reflects the persisted query in the search field (value + reset button).
    setSearchField(query) {
        const input = this.searchInputElement();
        if (input) {
            input.value = query || "";
        }

        const button = this.resetSearchButtonElement();
        if (button) {
            button.classList.toggle("hidden", !(query && query.length > 0));
        }
    }

    // Reflects the persisted view in the views tabs (selected highlight). The
    // views component lives outside the turbo-stream targets, so we update it here.
    setViewHighlight(view) {
        // No persisted view: leave the server-rendered default highlight intact.
        if (!view) return;

        const root = this.element.closest(".mensa-table");
        if (!root) return;

        root.querySelectorAll('[data-mensa-views-target="view"]').forEach(
            (link) => {
                const linkView = link.getAttribute("data-view-id") || "";
                link.classList.toggle(
                    "selected",
                    view !== "" && linkView === view,
                );
            },
        );

        this.updateSearchPlaceholder();
    }

    // Reflects the selected view in the search field placeholder: "Search in
    // <view>" for a named view, or the plain default placeholder when the
    // default view is active. Reads the currently highlighted view link, so it
    // must run after the selected class has been set.
    updateSearchPlaceholder() {
        const input = this.searchInputElement();
        if (!input) return;

        const root = this.element.closest(".mensa-table");
        const selected = root
            ? root.querySelector('[data-mensa-views-target="view"].selected')
            : null;

        const viewId = selected
            ? selected.getAttribute("data-view-id") || ""
            : "";
        const isDefault = !selected || viewId === "" || viewId === "default";

        if (isDefault) {
            input.placeholder = input.dataset.defaultPlaceholder || "";
        } else {
            input.placeholder = (input.dataset.viewPlaceholder || "").replace(
                "{view}",
                selected.textContent.trim(),
            );
        }
    }

    searchInputElement() {
        const root = this.element.closest(".mensa-table");
        return root
            ? root.querySelector('[data-mensa-search-target="searchInput"]')
            : null;
    }

    resetSearchButtonElement() {
        const root = this.element.closest(".mensa-table");
        return root
            ? root.querySelector(
                  '[data-mensa-search-target="resetSearchButton"]',
              )
            : null;
    }

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
        this.writeStorage(
            this.searchStorageKey,
            query && query.length > 0 ? query : null,
        );
    }

    loadQuery() {
        return this.readStorage(this.searchStorageKey) || "";
    }

    persistView(view) {
        this.writeStorage(
            this.viewStorageKey,
            view && view.length > 0 ? view : null,
        );
    }

    loadView() {
        return this.readStorage(this.viewStorageKey) || "";
    }

    persistPage(page) {
        // Page 1 is the default, so there is nothing worth persisting.
        this.writeStorage(
            this.pageStorageKey,
            page && page !== "1" ? page : null,
        );
    }

    loadPage() {
        return this.readStorage(this.pageStorageKey) || "";
    }

    persistOrder(order) {
        this.writeStorage(
            this.orderStorageKey,
            order && Object.keys(order).length > 0
                ? JSON.stringify(order)
                : null,
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
        } catch (e) {
            // localStorage may be unavailable (private mode / disabled); ignore.
        }
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

    get filtersStorageKey() {
        return `mensa:filters:${this.tableNameValue}`;
    }

    get searchStorageKey() {
        return `mensa:search:${this.tableNameValue}`;
    }

    get viewStorageKey() {
        return `mensa:view:${this.tableNameValue}`;
    }

    get pageStorageKey() {
        return `mensa:page:${this.tableNameValue}`;
    }

    get orderStorageKey() {
        return `mensa:order:${this.tableNameValue}`;
    }

    get ourUrl() {
        const url = this.mensaTableOutlet.ourUrl;
        return url;
    }
}
