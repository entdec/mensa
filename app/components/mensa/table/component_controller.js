import ApplicationController from "mensa/controllers/application_controller";
import { get } from "@rails/request.js";

export default class TableComponentController extends ApplicationController {
    static targets = [
        "controlBar", // Bar with buttons
        "condenseExpandIcon", // Icon
        "filterList", // Tabs or list of filters
        "views", // Tabs or list of views
        "viewButtons", // Cancel and save buttons for views
        "search", // Search bar
        "view", // View contains table element
        "turboFrame", // The turbo-frame
    ];
    static outlets = ["mensa-filter-pill-list"];
    static values = {
        supportsViews: Boolean,
        tableUrl: String,
    };

    connect() {
        super.connect();

        // The initial frame load is deferred so the filter pill list controller
        // can load it together with any persisted filters in a single request
        // (see mensa-filter-pill-list#restoreFilters). This avoids a second
        // backend call and a flash of unfiltered content. As a safety net, if
        // that controller never takes over, we load the frame ourselves.
        this.frameLoadFallback = setTimeout(() => this.loadFrame(), 100);
    }

    disconnect() {
        if (this.frameLoadFallback) {
            clearTimeout(this.frameLoadFallback);
            this.frameLoadFallback = null;
        }
    }

    // Triggers the turbo-frame's initial load. Idempotent: the frame is only
    // ever loaded once, whether that happens here or via a filtered restore that
    // claims the load by setting `frameLoadHandled`.
    //
    // The template intentionally omits the frame's `src` so it does not
    // auto-load the unfiltered table; we set it here instead. This lets the
    // filter pill list controller load the filtered table in a single request
    // (without a second, unfiltered request racing/overwriting it).
    loadFrame() {
        if (this.frameLoadHandled) return;
        this.frameLoadHandled = true;

        if (this.frameLoadFallback) {
            clearTimeout(this.frameLoadFallback);
            this.frameLoadFallback = null;
        }

        if (this.hasTurboFrameTarget && this.hasTableUrlValue) {
            this.turboFrameTarget.setAttribute("src", this.tableUrlValue);
        }
    }

    openFiltersAndSearch(event) {
        event.preventDefault();

        this.showFiltersAndSearch();
    }

    // Puts the table into the "filtering" UI state (open search, show the filter
    // bar and hide the views tabs). Extracted so it can be triggered both by a
    // user click and when persisted filters are restored on page load.
    showFiltersAndSearch() {
        if (this.supportsViewsValue) {
            if (this.hasViewButtonsTarget)
                this.viewButtonsTarget.classList.remove("hidden");
            if (this.hasSearchTarget)
                this.searchTarget.classList.remove("hidden");
            if (this.hasViewsTarget) this.viewsTarget.classList.add("hidden");
            if (this.hasFilterListTarget)
                this.filterListTarget.classList.remove("hidden");
        } else {
            if (this.hasControlBarTarget)
                this.controlBarTarget.classList.add("hidden");
            if (this.hasViewButtonsTarget)
                this.viewButtonsTarget.classList.remove("hidden");
            if (this.hasFilterListTarget)
                this.filterListTarget.classList.remove("hidden");
        }
    }

    cancelFiltersAndSearch(event) {
        event.preventDefault();

        // Discard all applied filters (and their persisted local storage copy)
        // before collapsing the filter/search chrome.
        if (this.hasMensaFilterPillListOutlet) {
            this.mensaFilterPillListOutlet.clearFilters();
        }

        if (this.supportsViewsValue) {
            this.searchTarget.classList.add("hidden");
            this.viewButtonsTarget.classList.add("hidden");
            this.filterListTarget.classList.add("hidden");
            this.viewsTarget.classList.remove("hidden");
        } else {
            this.controlBarTarget.classList.remove("hidden");
            this.viewButtonsTarget.classList.add("hidden");
            this.filterListTarget.classList.add("hidden");
        }
    }

    saveFiltersAndSearch(event) {
        event.preventDefault();
    }

    condenseExpand(event) {
        event.preventDefault();

        if (this.viewTarget.classList.contains("mensa-table__condensed")) {
            this.viewTarget.classList.remove("mensa-table__condensed");
            this.condenseExpandIconTarget.classList.add("fa-compress");
            this.condenseExpandIconTarget.classList.remove("fa-expand");
        } else {
            this.viewTarget.classList.add("mensa-table__condensed");
            this.condenseExpandIconTarget.classList.remove("fa-compress");
            this.condenseExpandIconTarget.classList.add("fa-expand");
        }
    }

    export(event) {
        event.preventDefault();

        let url = this.ourUrl;
        url.pathname += ".xlsx";
        get(url, {}).then(() => {});
    }

    get ourUrl() {
        // Prefer the frame's current src so navigation state (pagination, etc.)
        // is preserved; fall back to the configured table URL (the frame has no
        // src until it is loaded) and finally to the current location.
        if (
            this.hasTurboFrameTarget &&
            this.turboFrameTarget.getAttribute("src")
        ) {
            return new URL(this.turboFrameTarget.getAttribute("src"));
        }
        if (this.hasTableUrlValue && this.tableUrlValue) {
            return new URL(this.tableUrlValue);
        }
        return new URL(window.location.href);
    }
}
