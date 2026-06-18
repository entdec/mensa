import ApplicationController from "mensa/controllers/application_controller";
import { get, post, patch } from "@rails/request.js";

export default class TableComponentController extends ApplicationController {
    static targets = [
        "controlBar",
        "filterList",
        "views",
        "view",
        "scrollContainer",
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
        "eyeButton",
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
        this.scrollLeft = 0;
    }

    disconnect() {
        if (this.frameLoadFallback) {
            clearTimeout(this.frameLoadFallback);
            this.frameLoadFallback = null;
        }
    }

    saveDropdownOutsideHandler(event) {
        if (
            !this.hasSaveDropdownTarget ||
            this.saveDropdownTarget.classList.contains("hidden")
        ) {
            return;
        }

        const saveArea = this.saveDropdownTarget.closest(".relative");
        if (saveArea && !saveArea.contains(event.target)) {
            this.saveDropdownTarget.classList.add("hidden");
        }
    }

    captureNavigation() {
        if (!this.hasMensaFilterPillListOutlet) return;
        if (!this.hasTurboFrameTarget) return;
        const src = this.turboFrameTarget.getAttribute("src");
        if (!src) return;
        this.mensaFilterPillListOutlet.captureNavigation(src);
    }

    beforeFrameRender() {
        this.captureScrollPosition();
        this.isReplacingFrame = true;
    }

    scrollContainerTargetConnected(element) {
        this.scrollContainer = this.scrollableElementFor(element);
        this.restoreScrollPosition();
        this.scrollHandler = () => this.captureScrollPosition();
        this.scrollContainer.addEventListener("scroll", this.scrollHandler);
    }

    scrollContainerTargetDisconnected(element) {
        const scrollContainer =
            this.scrollContainer || this.scrollableElementFor(element);
        if (this.scrollHandler && scrollContainer) {
            scrollContainer.removeEventListener("scroll", this.scrollHandler);
        }
        this.scrollContainer = null;
    }

    captureScrollPosition(source = null) {
        if (this.isReplacingFrame || this.isRestoringScroll) return;
        const scrollContainer = this.scrollContainerFrom(source);
        if (!scrollContainer) return;
        this.scrollLeft = scrollContainer.scrollLeft;
    }

    restoreScrollPosition() {
        const scrollContainer = this.scrollContainerFrom();
        if (!scrollContainer) return;

        this.isRestoringScroll = true;
        scrollContainer.scrollLeft = this.scrollLeft || 0;
        requestAnimationFrame(() => {
            this.isRestoringScroll = false;
            this.isReplacingFrame = false;
        });
    }

    scrollContainerFrom(source = null) {
        if (source?.currentTarget) {
            return this.scrollableElementFor(source.currentTarget);
        }
        if (source?.scrollLeft !== undefined) return source;
        if (this.scrollContainer) return this.scrollContainer;
        if (this.hasScrollContainerTarget) {
            return this.scrollableElementFor(this.scrollContainerTarget);
        }
        return null;
    }

    scrollableElementFor(element) {
        if (!element) return null;
        if (element.scrollWidth > element.clientWidth) return element;

        return (
            Array.from(element.querySelectorAll("*")).find(
                (candidate) => candidate.scrollWidth > candidate.clientWidth,
            ) || element
        );
    }

    loadFrame() {
        if (this.frameLoadHandled) return;
        this.frameLoadHandled = true;

        if (this.frameLoadFallback) {
            clearTimeout(this.frameLoadFallback);
            this.frameLoadFallback = null;
        }

        if (!this.hasTurboFrameTarget) return;

        // When the filter-pill-list outlet is available, build the frame URL from the
        // full saved state (filters, view, order, …) so that captureNavigation doesn't
        // call persistView("") and wipe the active view from localStorage.
        // This happens on back-navigation: the outlet is connected before loadFrame is
        // called, but tableUrlValue was computed from the initial page URL which never
        // carries table_view_id.
        if (this.hasMensaFilterPillListOutlet) {
            const outlet = this.mensaFilterPillListOutlet;
            const state = {
                query: outlet.loadQuery(),
                view: outlet.loadView(),
                order: outlet.loadOrder(),
                page: outlet.loadPage(),
            };
            if (outlet.hasPersistedFilters())
                state.filters = outlet.loadFilters();
            this.turboFrameTarget.setAttribute(
                "src",
                outlet.buildUrl(state).toString(),
            );
        } else if (this.hasTableUrlValue) {
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
        if (this.hasSaveDropdownTarget)
            this.saveDropdownTarget.classList.add("hidden");

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
        if (!this.hasSaveDropdownTarget) return;
        const isHidden = this.saveDropdownTarget.classList.contains("hidden");
        this.saveDropdownTarget.classList.toggle("hidden");
        if (isHidden) {
            const rect = event.currentTarget.getBoundingClientRect();
            this.saveDropdownTarget.style.top = `${rect.bottom + 4}px`;
            this.saveDropdownTarget.style.right = `${window.innerWidth - rect.right}px`;
            this.saveDropdownTarget.style.left = "auto";
        }
    }

    // "Save as new view" — always opens the name dialog
    saveAsNewView(event) {
        if (event) event.preventDefault();
        if (this.hasSaveDropdownTarget)
            this.saveDropdownTarget.classList.add("hidden");
        this._openSaveDialog();
    }

    // "Update view" — updates the currently selected user-owned view in place
    async updateCurrentViewAction(event) {
        if (event) event.preventDefault();
        if (this.hasSaveDropdownTarget)
            this.saveDropdownTarget.classList.add("hidden");

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
                turbo_frame_id: this.hasTurboFrameTarget
                    ? this.turboFrameTarget.id
                    : null,
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
                column_order: state.column_order,
                hidden_columns: state.hidden_columns,
                turbo_frame_id: this.hasTurboFrameTarget
                    ? this.turboFrameTarget.id
                    : null,
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

    // Called when the filter-pill-list outlet connects (including after turbo-stream re-renders).
    // Re-applied on every connect so late-arriving pills (from restoreState) get the right state.
    mensaFilterPillListOutletConnected() {
        const hasViewFilters = this._hasViewFilterPills();
        if (hasViewFilters) {
            const visible = this._loadViewFiltersVisible();
            this.element.classList.toggle(
                "mensa-table--view-filters-hidden",
                !visible,
            );
        } else {
            this.element.classList.remove("mensa-table--view-filters-hidden");
        }
        this._updateEyeButton();
    }

    // Called from the filter-pill-list controller when the user selects a different view.
    // Resets the eye preference to hidden so the new view's filters start collapsed.
    // Does NOT call _updateEyeButton() — the old DOM is still present here and would cause
    // _updateEyeButton to remove the class we just added. The proper update happens in
    // mensaFilterPillListOutletConnected after the turbo-stream re-render.
    viewChanged() {
        this._saveViewFiltersVisible(false);
        this.element.classList.add("mensa-table--view-filters-hidden");
    }

    // --- Eye toggle (view-origin filter pills) ---

    toggleViewFilters(event) {
        if (event) event.preventDefault();
        const nowHidden = this.element.classList.toggle(
            "mensa-table--view-filters-hidden",
        );
        this._saveViewFiltersVisible(!nowHidden);
        this._updateEyeButton();
    }

    _hasViewFilterPills() {
        return (
            this.element.querySelectorAll('[data-view-filter="true"]').length >
            0
        );
    }

    // Only updates button visibility and icon — never touches the hidden class.
    // Class management is the sole responsibility of mensaFilterPillListOutletConnected
    // and toggleViewFilters.
    _updateEyeButton() {
        const hasViewFilters = this._hasViewFilterPills();

        if (!this.hasEyeButtonTarget) return;

        this.eyeButtonTarget.classList.toggle("hidden", !hasViewFilters);

        if (hasViewFilters) {
            const hidden = this.element.classList.contains(
                "mensa-table--view-filters-hidden",
            );
            const visibleIconClass =
                this.eyeButtonTarget.dataset.iconVisibleClass || "";
            const hiddenIconClass =
                this.eyeButtonTarget.dataset.iconHiddenClass || "";

            // Replace innerHTML so FontAwesome's MutationObserver re-processes the new <i>
            this.eyeButtonTarget.innerHTML = hidden
                ? `<i class="${visibleIconClass}"></i>`
                : `<i class="${hiddenIconClass}"></i>`;
        }
    }

    // --- View filter visibility persistence ---

    _viewFiltersStorageKey() {
        return `mensa:view-filters-visible:${this._tableName()}`;
    }

    _tableName() {
        if (this.hasMensaFilterPillListOutlet) {
            return this.mensaFilterPillListOutlet.tableNameValue;
        }
        const el = this.element.querySelector(
            "[data-mensa-filter-pill-list-table-name-value]",
        );
        return el?.dataset?.mensaFilterPillListTableNameValue || "";
    }

    _loadViewFiltersVisible() {
        try {
            return (
                window.localStorage.getItem(this._viewFiltersStorageKey()) ===
                "true"
            );
        } catch (e) {
            return false;
        }
    }

    _saveViewFiltersVisible(visible) {
        try {
            if (visible) {
                window.localStorage.setItem(
                    this._viewFiltersStorageKey(),
                    "true",
                );
            } else {
                window.localStorage.removeItem(this._viewFiltersStorageKey());
            }
        } catch (e) {}
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

    toggleExportRepeat() {
        const dialog = this.exportDialogTarget;
        const options = dialog.querySelector(
            "[data-mensa-table-repeat-options]",
        );
        if (!options) return;

        const mode = dialog.querySelector(
            'input[name="repeat_mode"]:checked',
        )?.value;
        options.hidden = mode !== "repeating";
    }

    confirmExport(event) {
        event.preventDefault();
        if (!this.hasExportsUrlValue) return;

        const dialog = this.exportDialogTarget;
        const scope =
            dialog.querySelector('input[name="scope"]:checked')?.value || "all";
        const exportFormat =
            dialog.querySelector('input[name="export_format"]:checked')
                ?.value || "csv_excel";
        const repeatMode = dialog.querySelector(
            'input[name="repeat_mode"]:checked',
        )?.value;
        const repeat =
            repeatMode === "repeating"
                ? dialog.querySelector('select[name="repeat"]')?.value || ""
                : "";

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
                repeat,
                table_view_id: view,
                page: nav.page,
                query: state.query || nav.query,
                filters: state.filters,
                order: state.order,
                column_order: state.column_order,
                hidden_columns: state.hidden_columns,
            }),
            contentType: "application/json",
            responseKind: "turbo-stream",
        });
    }

    get ourUrl() {
        if (
            this.hasTurboFrameTarget &&
            this.turboFrameTarget.getAttribute("src")
        ) {
            return new URL(
                this.turboFrameTarget.getAttribute("src"),
                window.location.origin,
            );
        }
        if (this.hasTableUrlValue && this.tableUrlValue) {
            return new URL(this.tableUrlValue, window.location.origin);
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
        this.saveSimpleTargets.forEach((t) =>
            t.classList.toggle("hidden", isUserView),
        );
        this.saveSplitTargets.forEach((t) =>
            t.classList.toggle("hidden", !isUserView),
        );
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
        if (this.hasSaveViewDescriptionTarget)
            this.saveViewDescriptionTarget.value = "";
        if (typeof this.saveViewDialogTarget.showModal === "function") {
            this.saveViewDialogTarget.showModal();
        } else {
            this.saveViewDialogTarget.setAttribute("open", "");
        }
        if (this.hasSaveViewNameTarget) this.saveViewNameTarget.focus();
    }
}
