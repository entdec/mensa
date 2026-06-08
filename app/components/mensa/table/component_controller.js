import ApplicationController from "mensa/controllers/application_controller";
import { get, post, patch } from "@rails/request.js";

export default class TableComponentController extends ApplicationController {
    static targets = [
        "controlBar",
        "filterList",
        "views",
        "view",
        "turboFrame",
        "saveViewDialog",
        "saveViewName",
        "saveViewDescription",
        "exportDialog",
        "exportIcon",
        "saveResetButtons",
        "saveDropdown",
        "saveSimple",
        "saveSplit",
    ];
    static outlets = ["mensa-filter-pill-list", "mensa-column-customizer"];
    static values = {
        supportsViews: Boolean,
        tableUrl: String,
        saveViewUrl: String,
        viewsUrl: String,
        exportsUrl: String,
    };

    connect() {
        super.connect();

        this.frameLoadFallback = setTimeout(() => this.loadFrame(), 100);

        if (this.hasTurboFrameTarget) {
            this.captureNavigationHandler = () => this.captureNavigation();
            this.turboFrameTarget.addEventListener(
                "turbo:frame-load",
                this.captureNavigationHandler,
            );
        }

        // Close save dropdown when clicking outside
        this._saveDropdownOutsideHandler = (e) => {
            if (this.hasSaveDropdownTarget && !this.saveDropdownTarget.classList.contains("hidden")) {
                const saveArea = this.saveDropdownTarget.closest(".relative");
                if (saveArea && !saveArea.contains(e.target)) {
                    this.saveDropdownTarget.classList.add("hidden");
                }
            }
        };
        document.addEventListener("click", this._saveDropdownOutsideHandler);
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

        document.removeEventListener("click", this._saveDropdownOutsideHandler);
    }

    captureNavigation() {
        if (!this.hasMensaFilterPillListOutlet) return;
        if (!this.hasTurboFrameTarget) return;
        const src = this.turboFrameTarget.getAttribute("src");
        if (!src) return;
        this.mensaFilterPillListOutlet.captureNavigation(src);
    }

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

    // --- Save/Reset button visibility ---

    showSaveReset() {
        if (this.hasSaveResetButtonsTarget) {
            this.saveResetButtonsTarget.classList.remove("hidden");
        }
    }

    hideSaveReset() {
        if (this.hasSaveResetButtonsTarget) {
            this.saveResetButtonsTarget.classList.add("hidden");
        }
    }

    // Called whenever a filter or search changes so the save/reset buttons appear.
    notifyUnsavedState() {
        this._updateSaveButtonMode();
        this.showSaveReset();
    }

    // --- Cancel / Reset ---

    // Resets all filters, search, and column customisation to the active view's clean state.
    cancelFiltersAndSearch(event) {
        if (event) event.preventDefault();
        this.hideSaveReset();
        if (this.hasSaveDropdownTarget) this.saveDropdownTarget.classList.add("hidden");

        if (this.hasMensaFilterPillListOutlet) {
            this.mensaFilterPillListOutlet.clearFiltersAndSearch();
        }
        if (this.hasMensaColumnCustomizerOutlet) {
            this.mensaColumnCustomizerOutlet.resetToDefault();
        }
    }

    // --- Save ---

    toggleSaveDropdown(event) {
        event.preventDefault();
        event.stopPropagation();
        if (this.hasSaveDropdownTarget) {
            this.saveDropdownTarget.classList.toggle("hidden");
        }
    }

    // "Save as new view" — always opens the name dialog
    saveAsNewView(event) {
        if (event) event.preventDefault();
        if (this.hasSaveDropdownTarget) this.saveDropdownTarget.classList.add("hidden");
        this._openSaveDialog();
    }

    // "Update view" — updates the currently selected user-owned view in place
    async updateCurrentViewAction(event) {
        if (event) event.preventDefault();
        if (this.hasSaveDropdownTarget) this.saveDropdownTarget.classList.add("hidden");

        const viewId = this._selectedUserViewId();
        if (!viewId) {
            this._openSaveDialog();
            return;
        }
        await this._updateCurrentView(viewId);
    }

    // Legacy: called from the old "Save" button. Routes to update-in-place for
    // user views, otherwise opens the dialog.
    saveFiltersAndSearch(event) {
        if (event) event.preventDefault();
        const viewId = this._selectedUserViewId();
        if (viewId) {
            this._updateCurrentView(viewId);
        } else {
            this._openSaveDialog();
        }
    }

    async _updateCurrentView(viewId) {
        const state = this.currentViewState();
        this.hideSaveReset();

        const response = await patch(`${this.saveViewUrlValue}/${viewId}`, {
            body: JSON.stringify({
                query: state.query,
                filters: state.filters,
                order: state.order,
                column_order: state.column_order,
                hidden_columns: state.hidden_columns,
                turbo_frame_id: this.hasTurboFrameTarget ? this.turboFrameTarget.id : null,
            }),
            contentType: "application/json",
            responseKind: "turbo-stream",
        });

        if (response.ok && this.hasMensaFilterPillListOutlet) {
            this.mensaFilterPillListOutlet.clearPersistedDirtyState();
            this.mensaFilterPillListOutlet.persistView(viewId);
        }
    }

    cancelSaveView(event) {
        if (event) event.preventDefault();
        this.closeSaveViewDialog();
    }

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

    async confirmSaveView(event) {
        event.preventDefault();

        const name = this.hasSaveViewNameTarget ? this.saveViewNameTarget.value.trim() : "";
        if (!name) {
            if (this.hasSaveViewNameTarget) this.saveViewNameTarget.reportValidity();
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
                column_order: state.column_order,
                hidden_columns: state.hidden_columns,
                turbo_frame_id: this.hasTurboFrameTarget ? this.turboFrameTarget.id : null,
            }),
            contentType: "application/json",
            responseKind: "turbo-stream",
        });

        if (response.ok) {
            this.closeSaveViewDialog();
            this.hideSaveReset();
            if (this.hasMensaFilterPillListOutlet) {
                this.mensaFilterPillListOutlet.clearPersistedDirtyState();
            }
            // After Turbo processes the stream the views component re-renders with
            // the new view selected — read its ID from the DOM and persist it.
            setTimeout(() => this._persistSelectedViewId(), 0);
        }
    }

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
            column_order: outlet.loadColumnOrder(),
            hidden_columns: outlet.loadHiddenColumns(),
        };
    }

    viewTargetConnected() {}

    filterListTargetConnected(element) {
        // The filter bar is always visible in the new design — nothing to toggle.
    }

    // --- Export ---

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

    confirmExport(event) {
        event.preventDefault();
        if (!this.hasExportsUrlValue) return;

        const dialog = this.exportDialogTarget;
        const scope = dialog.querySelector('input[name="scope"]:checked')?.value || "all";
        const exportFormat = dialog.querySelector('input[name="export_format"]:checked')?.value || "csv_excel";

        const state = this.currentViewState();
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
        if (this.hasTurboFrameTarget && this.turboFrameTarget.getAttribute("src")) {
            return new URL(this.turboFrameTarget.getAttribute("src"));
        }
        if (this.hasTableUrlValue && this.tableUrlValue) {
            return new URL(this.tableUrlValue);
        }
        return new URL(window.location.href);
    }

    // --- Private ---

    // Reads the currently-selected view ID from the DOM (after Turbo re-renders
    // the views component) and persists it to localStorage.
    _persistSelectedViewId() {
        if (!this.hasMensaFilterPillListOutlet) return;
        const checked = Array.from(
            this.element.querySelectorAll('[data-mensa-views-target="view"]'),
        ).find((el) => {
            const check = el.querySelector(".mensa-table__views__option-check");
            return check && !check.classList.contains("invisible");
        });
        const viewId = checked?.dataset.viewId || "";
        this.mensaFilterPillListOutlet.persistView(viewId);
    }

    // Show the plain "Save" button for system/default views, and the dropdown
    // "Save ▾" button for user-created views.
    _updateSaveButtonMode() {
        if (!this.hasSaveSimpleTarget && !this.hasSaveSplitTarget) return;
        const isUserView = !!this._selectedUserViewId();
        this.saveSimpleTargets.forEach((t) => t.classList.toggle("hidden", isUserView));
        this.saveSplitTargets.forEach((t) => t.classList.toggle("hidden", !isUserView));
    }

    _selectedUserViewId() {
        const selectedViewEl = this.element.querySelector(
            '[data-mensa-views-target="view"]',
        );
        // Find the one whose check is visible
        const checked = Array.from(
            this.element.querySelectorAll('[data-mensa-views-target="view"]'),
        ).find((el) => {
            const check = el.querySelector(".mensa-table__views__option-check");
            return check && !check.classList.contains("invisible");
        });
        const viewId = checked?.getAttribute("data-view-id") || "";
        // UUID-based IDs are user-created views
        return viewId && /[a-f0-9-]{32}$/.test(viewId) ? viewId : null;
    }

    _openSaveDialog() {
        if (!this.hasSaveViewDialogTarget) return;
        if (this.hasSaveViewNameTarget) this.saveViewNameTarget.value = "";
        if (this.hasSaveViewDescriptionTarget) this.saveViewDescriptionTarget.value = "";
        if (typeof this.saveViewDialogTarget.showModal === "function") {
            this.saveViewDialogTarget.showModal();
        } else {
            this.saveViewDialogTarget.setAttribute("open", "");
        }
        if (this.hasSaveViewNameTarget) this.saveViewNameTarget.focus();
    }
}
