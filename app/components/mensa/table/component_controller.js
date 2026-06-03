import ApplicationController from "mensa/controllers/application_controller";
import { get, post } from "@rails/request.js";

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
        "saveViewDialog", // Dialog asking for a view name/description
        "saveViewName", // Name input inside the save-view dialog
        "saveViewDescription", // Description input inside the save-view dialog
    ];
    static outlets = ["mensa-filter-pill-list"];
    static values = {
        supportsViews: Boolean,
        tableUrl: String,
        saveViewUrl: String,
    };

    connect() {
        super.connect();

        // The initial frame load is deferred so the filter pill list controller
        // can load it together with any persisted filters in a single request
        // (see mensa-filter-pill-list#restoreState). This avoids a second
        // backend call and a flash of unfiltered content. As a safety net, if
        // that controller never takes over, we load the frame ourselves.
        this.frameLoadFallback = setTimeout(() => this.loadFrame(), 100);

        // Pagination, sorting and view tabs navigate the turbo-frame directly.
        // Capture the resulting page/view so they can be persisted and restored.
        if (this.hasTurboFrameTarget) {
            this.captureNavigationHandler = () => this.captureNavigation();
            this.turboFrameTarget.addEventListener(
                "turbo:frame-load",
                this.captureNavigationHandler,
            );
        }
    }

    disconnect() {
        if (this.frameLoadFallback) {
            clearTimeout(this.frameLoadFallback);
            this.frameLoadFallback = null;
        }

        if (this.hasTurboFrameTarget && this.captureNavigationHandler) {
            this.turboFrameTarget.removeEventListener(
                "turbo:frame-load",
                this.captureNavigationHandler,
            );
        }
    }

    // Forwards the frame's current URL to the filter pill list so it can persist
    // the page and selected view after a turbo-frame navigation.
    captureNavigation() {
        if (!this.hasMensaFilterPillListOutlet) return;
        if (!this.hasTurboFrameTarget) return;

        const src = this.turboFrameTarget.getAttribute("src");
        if (!src) return;

        this.mensaFilterPillListOutlet.captureNavigation(src);
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

        // Discard all applied filters and the search query (and their persisted
        // local storage copies) before collapsing the filter/search chrome.
        if (this.hasMensaFilterPillListOutlet) {
            this.mensaFilterPillListOutlet.clearFiltersAndSearch();
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

    // Opens the dialog that asks the user for a name and description before the
    // current filters/ordering/search are persisted as a custom view. The button
    // (and this dialog) only exist when there is a current user to own the view.
    saveFiltersAndSearch(event) {
        event.preventDefault();

        if (!this.hasSaveViewDialogTarget) return;

        if (this.hasSaveViewNameTarget) this.saveViewNameTarget.value = "";
        if (this.hasSaveViewDescriptionTarget)
            this.saveViewDescriptionTarget.value = "";

        if (typeof this.saveViewDialogTarget.showModal === "function") {
            this.saveViewDialogTarget.showModal();
        } else {
            this.saveViewDialogTarget.setAttribute("open", "");
        }

        if (this.hasSaveViewNameTarget) this.saveViewNameTarget.focus();
    }

    cancelSaveView(event) {
        if (event) event.preventDefault();
        this.closeSaveViewDialog();
    }

    // Closes the dialog when the user clicks the backdrop (outside the form).
    // A click on the backdrop reports the dialog element itself as the target.
    saveViewDialogBackdrop(event) {
        if (event.target === this.saveViewDialogTarget) {
            this.closeSaveViewDialog();
        }
    }

    closeSaveViewDialog() {
        if (!this.hasSaveViewDialogTarget) return;

        if (typeof this.saveViewDialogTarget.close === "function") {
            this.saveViewDialogTarget.close();
        } else {
            this.saveViewDialogTarget.removeAttribute("open");
        }
    }

    // Collects the currently applied filters, ordering and search query and
    // posts them to the server to be stored as a named view for the current
    // user. On success the page is reloaded so the new view appears in the tabs.
    async confirmSaveView(event) {
        event.preventDefault();

        const name = this.hasSaveViewNameTarget
            ? this.saveViewNameTarget.value.trim()
            : "";
        if (!name) {
            if (this.hasSaveViewNameTarget)
                this.saveViewNameTarget.reportValidity();
            return;
        }

        const description = this.hasSaveViewDescriptionTarget
            ? this.saveViewDescriptionTarget.value.trim()
            : "";

        const state = this.currentViewState();

        const response = await post(this.saveViewUrlValue, {
            body: JSON.stringify({
                name,
                description,
                query: state.query,
                filters: state.filters,
                order: state.order,
            }),
            contentType: "application/json",
            responseKind: "json",
        });

        if (response.ok) {
            this.closeSaveViewDialog();
            window.location.reload();
        }
    }

    // Reads the active filters, search query and sort order via the filter pill
    // list controller, which owns that state.
    currentViewState() {
        if (!this.hasMensaFilterPillListOutlet) {
            return { filters: {}, query: "", order: {} };
        }

        const outlet = this.mensaFilterPillListOutlet;
        const input = outlet.searchInputElement();

        return {
            filters: outlet.collectFilters(),
            query: input ? input.value : outlet.loadQuery(),
            order: outlet.loadOrder(),
        };
    }

    condenseExpand(event) {
        event.preventDefault();

        if (!this.hasViewTarget) return;

        const condensed = !this.viewTarget.classList.contains(
            "mensa-table__condensed",
        );
        this.applyCondensed(condensed);

        // Persist the condensed preference so it survives a page refresh. It is
        // a client-only toggle (no server param), so the filter pill list just
        // stores the flag for us.
        if (this.hasMensaFilterPillListOutlet) {
            this.mensaFilterPillListOutlet.persistCondensed(condensed);
        }
    }

    // Applies the condensed/expanded state to the rendered view and its icon.
    applyCondensed(condensed) {
        if (!this.hasViewTarget) return;

        this.viewTarget.classList.toggle("mensa-table__condensed", condensed);

        if (this.hasCondenseExpandIconTarget) {
            this.condenseExpandIconTarget.classList.toggle(
                "fa-compress",
                !condensed,
            );
            this.condenseExpandIconTarget.classList.toggle(
                "fa-expand",
                condensed,
            );
        }
    }

    // The view target is (re)rendered inside the turbo-frame on every load. When
    // it appears, re-apply any persisted condensed preference.
    viewTargetConnected() {
        if (!this.hasMensaFilterPillListOutlet) return;

        const condensed = this.mensaFilterPillListOutlet.loadCondensed();
        if (condensed !== null) {
            this.applyCondensed(condensed);
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
