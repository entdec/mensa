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
        "exportDialog", // Dialog listing downloads and offering a new export
    ];
    static outlets = ["mensa-filter-pill-list"];
    static values = {
        supportsViews: Boolean,
        tableUrl: String,
        saveViewUrl: String,
        exportsUrl: String,
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
        this.filterBarIsOpen = true;

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
        this.filterBarIsOpen = false;

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

    // Called by Stimulus whenever the filterList target element is connected —
    // including after a turbo-stream swaps the filter pill list for a fresh
    // render (which always has the .hidden class baked in). If the user had the
    // bar open at the time, keep it open.
    filterListTargetConnected(element) {
        if (this.filterBarIsOpen) {
            element.classList.remove("hidden");
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
    // user. On success, the server returns a turbo-stream that updates the
    // views tabs, filter pill list, and table data in one shot.
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

        // Clear the open flag before the request so that when the turbo-stream
        // swaps the filter list target, filterListTargetConnected does not
        // immediately re-open the bar.
        this.filterBarIsOpen = false;

        const response = await post(this.saveViewUrlValue, {
            body: JSON.stringify({
                name,
                description,
                query: state.query,
                filters: state.filters,
                order: state.order,
                // Sent so the server can reconstruct matching element IDs.
                turbo_frame_id: this.hasTurboFrameTarget
                    ? this.turboFrameTarget.id
                    : null,
            }),
            contentType: "application/json",
            responseKind: "turbo-stream",
        });

        if (response.ok) {
            this.closeSaveViewDialog();
            this.collapseToViewsMode();
        }
    }

    // Closes the filter/search bar and restores the views-tab chrome, without
    // clearing filters. Used after a successful view save where the turbo-stream
    // response has already updated all the relevant data.
    collapseToViewsMode() {
        if (this.supportsViewsValue) {
            if (this.hasSearchTarget) this.searchTarget.classList.add("hidden");
            if (this.hasViewButtonsTarget)
                this.viewButtonsTarget.classList.add("hidden");
            if (this.hasFilterListTarget)
                this.filterListTarget.classList.add("hidden");
            if (this.hasViewsTarget)
                this.viewsTarget.classList.remove("hidden");
        } else {
            if (this.hasControlBarTarget)
                this.controlBarTarget.classList.remove("hidden");
            if (this.hasViewButtonsTarget)
                this.viewButtonsTarget.classList.add("hidden");
            if (this.hasFilterListTarget)
                this.filterListTarget.classList.add("hidden");
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

    // The view target is (re)rendered inside the turbo-frame on every load.
    viewTargetConnected() {
        if (!this.hasMensaFilterPillListOutlet) return;
    }

    // Opens the export dialog. The downloads list is refreshed first (via a
    // Turbo stream response) so the user always sees their current downloads,
    // then the dialog is shown.
    export(event) {
        event.preventDefault();

        if (!this.hasExportDialogTarget) return;

        if (this.hasExportsUrlValue && this.exportsUrlValue) {
            get(this.exportsUrlValue, { responseKind: "turbo-stream" }).finally(
                () => this.openExportDialog(),
            );
        } else {
            this.openExportDialog();
        }
    }

    openExportDialog() {
        if (!this.hasExportDialogTarget) return;

        if (typeof this.exportDialogTarget.showModal === "function") {
            this.exportDialogTarget.showModal();
        } else {
            this.exportDialogTarget.setAttribute("open", "");
        }
    }

    cancelExport(event) {
        if (event) event.preventDefault();
        this.closeExportDialog();
    }

    // Closes the dialog when the user clicks the backdrop (outside the panel).
    exportDialogBackdrop(event) {
        if (event.target === this.exportDialogTarget) {
            this.closeExportDialog();
        }
    }

    closeExportDialog() {
        if (!this.hasExportDialogTarget) return;

        if (typeof this.exportDialogTarget.close === "function") {
            this.exportDialogTarget.close();
        } else {
            this.exportDialogTarget.removeAttribute("open");
        }
    }

    // Creates a new export honouring the selected scope/format and the currently
    // applied filters, search and ordering. The dialog stays open so the new
    // (pending) download appears in the list; it is updated to a download link
    // via a Turbo stream broadcast once the background job finishes.
    confirmExport(event) {
        event.preventDefault();

        if (!this.hasExportsUrlValue) return;

        const dialog = this.exportDialogTarget;
        const scope =
            dialog.querySelector('input[name="scope"]:checked')?.value || "all";
        const exportFormat =
            dialog.querySelector('input[name="export_format"]:checked')
                ?.value || "csv_excel";

        const state = this.currentViewState();

        // The page and query come from the URL that rendered the table currently
        // on screen (see mensa-filter-pill-list#currentRequestState). This is
        // authoritative for what the user is viewing, whereas per-key local
        // storage can be missing the current page/query. Filters and order are
        // read from the live pills/storage so they stay correct even when a
        // navigation URL omits them.
        const nav = this.hasMensaFilterPillListOutlet
            ? this.mensaFilterPillListOutlet.currentRequestState()
            : { page: "", query: "", view: "" };
        const view = this.hasMensaFilterPillListOutlet
            ? this.mensaFilterPillListOutlet.loadView() || nav.view
            : "";

        post(this.exportsUrlValue, {
            body: JSON.stringify({
                scope,
                export_format: exportFormat,
                table_view_id: view,
                page: nav.page,
                query: state.query || nav.query,
                filters: state.filters,
                order: state.order,
            }),
            contentType: "application/json",
            responseKind: "turbo-stream",
        });
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
