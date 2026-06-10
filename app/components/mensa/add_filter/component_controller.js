import ApplicationController from "mensa/controllers/application_controller";
// import { debounce } from '@entdec/satis'
import { get } from "@rails/request.js";

// Survives the turbo-stream re-render that destroys both the filter-pill-list
// and add-filter controller instances on every refreshFilters() call.
let _pendingMultiReopen = null;

export default class AddFilterComponentController extends ApplicationController {
    static outlets = ["mensa-filter-pill-list"];
    static targets = [
        "filterList", // all filters
        "filterListItem", // individual filters
        "description", // contains the filter description in the "tab"
        "valuePopover", // contains the filter-value
        "value",
        "valueOption", // individual value list items in the popover
        "operatorOption", // individual operator list items
    ];
    static values = {
        supportsViews: Boolean,
    };

    connect() {
        super.connect();

        // this.filterValueEntered = debounce(this.filterValueEntered, 500).bind(this)
        // this.filterValueEntered = this.filterValueEntered.bind(this)
        this._selectedFilterColumn = null;
        this._outsideClickHandler = null;
        this._columnLabel = null;
        this._pendingPill = null;

        // If a multi-select toggle triggered a refreshFilters() that destroyed and
        // recreated this controller, re-open the value popover with the saved state.
        if (_pendingMultiReopen) {
            const reopen = _pendingMultiReopen;
            _pendingMultiReopen = null;
            // Defer one macrotask so Stimulus has time to wire up outlets.
            setTimeout(() => {
                if (this.hasMensaFilterPillListOutlet) {
                    this.editColumn(
                        reopen.column,
                        reopen.values,
                        reopen.operator || "is",
                        null,
                    );
                }
            }, 0);
        }

        // Prevent arrow keys from scrolling the page while any popup is open.
        // Bound once here (not on each showList/hideList) to avoid timing issues
        // with turbo-stream re-renders destroying the controller mid-flow.
        this._arrowPreventHandler = (event) => {
            if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return;
            const listOpen =
                this.hasFilterListTarget &&
                !this.filterListTarget.classList.contains("hidden");
            if (listOpen || this.isValuePopoverOpen) event.preventDefault();
        };
        document.addEventListener("keydown", this._arrowPreventHandler);
    }

    disconnect() {
        this._unbindOutsideClick();
        if (this._arrowPreventHandler) {
            document.removeEventListener("keydown", this._arrowPreventHandler);
            this._arrowPreventHandler = null;
        }
    }

    // Called when you click add-filter (legacy — kept for backward compatibility)
    toggle(event) {
        this.filterListTarget.classList.toggle("hidden");
    }

    // Called by the + button — always shows all columns regardless of current filter
    openAllColumns(event) {
        this.filterColumns("");
        this.showList(event?.currentTarget);
    }

    // Called by the filter-pill-list controller when the search input is focused
    // or receives input, so the column list appears under the search bar.
    // triggerEl: the element that triggered this (search input or + button), used
    // to align the dropdown horizontally to where the user actually is.
    showList(triggerEl = null) {
        this._triggerEl = triggerEl;
        this.filterListTarget.classList.remove("hidden");
        this._positionListUnderSearchBar(triggerEl);
        this._bindOutsideClick();
    }

    hideList() {
        this.filterListItemTargets.forEach((i) =>
            i.classList.remove("highlighted"),
        );
        this.filterListTarget.classList.add("hidden");
        this._unbindOutsideClick();
    }

    // Filters the visible column items to those matching `query`.
    filterColumns(query) {
        const q = (query || "").toLowerCase();
        this.filterListItemTargets.forEach((item) => {
            const label =
                item.querySelector(".label")?.textContent?.toLowerCase() || "";
            item.classList.toggle("hidden", q.length > 0 && !label.includes(q));
        });
    }

    // Filters the value option items in the open value popover to those matching `query`.
    // Operator options are never hidden — they don't represent data values.
    filterValues(query) {
        const q = (query || "").toLowerCase();
        this.valueOptionTargets.forEach((item) => {
            const label = (
                item.dataset.label ||
                item.dataset.value ||
                ""
            ).toLowerCase();
            item.classList.toggle("hidden", q.length > 0 && !label.includes(q));
        });
    }

    get visibleColumnCount() {
        return this.filterListItemTargets.filter(
            (i) => !i.classList.contains("hidden"),
        ).length;
    }

    get hasHighlightedColumn() {
        return !!this.filterListItemTargets.find((i) =>
            i.classList.contains("highlighted"),
        );
    }

    confirmHighlightedColumn() {
        const item = this.filterListItemTargets.find((i) =>
            i.classList.contains("highlighted"),
        );
        if (item) item.click();
    }

    // Re-opens the value popover for an already-applied filter (clicked pill),
    // pre-selected to its current value. Routes through the same popover/flow as
    // adding a brand new filter, so selecting a value re-requests the table.
    editColumn(columnName, value, operator, anchor) {
        this.selectedFilterColumn = columnName;
        this.editingValue = value;
        this.editingOperator = operator || null;
        this.anchorElement = anchor;

        // Resolve the human column label from the filter list so _updateDescription works.
        const item = this.filterListItemTargets.find(
            (li) => li.dataset.filterColumnName === columnName,
        );
        this._columnLabel =
            item?.querySelector(".label")?.innerText ?? columnName;

        this.openValuePopover();
    }

    // Keyboard navigation: move highlight down/up in the column list
    highlightNext() {
        const items = this.filterListItemTargets.filter(
            (i) => !i.classList.contains("hidden"),
        );
        if (!items.length) return;
        const current = items.findIndex((i) =>
            i.classList.contains("highlighted"),
        );
        const next = current < items.length - 1 ? current + 1 : 0;
        items.forEach((i) => i.classList.remove("highlighted"));
        items[next].classList.add("highlighted");
        items[next].scrollIntoView({ block: "nearest" });
    }

    highlightPrev() {
        const items = this.filterListItemTargets.filter(
            (i) => !i.classList.contains("hidden"),
        );
        if (!items.length) return;
        const current = items.findIndex((i) =>
            i.classList.contains("highlighted"),
        );
        const prev = current > 0 ? current - 1 : items.length - 1;
        items.forEach((i) => i.classList.remove("highlighted"));
        items[prev].classList.add("highlighted");
        items[prev].scrollIntoView({ block: "nearest" });
    }

    // Mouse hover on column list items — keeps highlight in sync with cursor
    columnItemHovered(event) {
        this.filterListItemTargets.forEach((i) =>
            i.classList.remove("highlighted"),
        );
        event.currentTarget.classList.add("highlighted");
    }

    // Keyboard navigation: move highlight down/up in the value popover (values + operators)
    highlightNextValue() {
        const items = this._valuePopoverItems;
        if (!items.length) return;
        const current = items.findIndex((i) =>
            i.classList.contains("highlighted"),
        );
        const next = current < items.length - 1 ? current + 1 : 0;
        items.forEach((i) => i.classList.remove("highlighted"));
        items[next].classList.add("highlighted");
        items[next].scrollIntoView({ block: "nearest" });
    }

    highlightPrevValue() {
        const items = this._valuePopoverItems;
        if (!items.length) return;
        const current = items.findIndex((i) =>
            i.classList.contains("highlighted"),
        );
        const prev = current > 0 ? current - 1 : items.length - 1;
        items.forEach((i) => i.classList.remove("highlighted"));
        items[prev].classList.add("highlighted");
        items[prev].scrollIntoView({ block: "nearest" });
    }

    // Mouse hover on value/operator items — keeps highlight in sync with cursor
    highlightItem(event) {
        this._valuePopoverItems.forEach((i) =>
            i.classList.remove("highlighted"),
        );
        event.currentTarget.classList.add("highlighted");
    }

    // Confirm the highlighted (or pre-selected) item in the value popover via Enter
    confirmHighlightedValue() {
        let item = this._valuePopoverItems.find((i) =>
            i.classList.contains("highlighted"),
        );
        // Fall back to pre-selected value option if nothing is keyboard-highlighted (single only)
        if (!item && !this.isMultipleMode && this.hasValueOptionTarget) {
            item = this.valueOptionTargets.find(
                (opt) => opt.dataset.selected === "true",
            );
        }
        if (!item) return;
        if (
            this.hasValueOptionTarget &&
            this.valueOptionTargets.includes(item)
        ) {
            if (this.isMultipleMode) {
                this._toggleValueItem(item);
            } else {
                this._selectValueItem(item);
            }
        } else {
            item.click(); // operator item
        }
    }

    // Click handler for custom value list items
    selectValue(event) {
        if (this.isMultipleMode) {
            this._toggleValueItem(event.currentTarget);
        } else {
            this._selectValueItem(event.currentTarget);
        }
    }

    get isValuePopoverOpen() {
        return (
            this.hasValuePopoverTarget &&
            !this.valuePopoverTarget.classList.contains("hidden")
        );
    }

    get isMultipleMode() {
        if (!this.hasValuePopoverTarget) return false;
        return (
            this.valuePopoverTarget.querySelector(
                ".mensa-table__add_filter__popover_container__values",
            )?.dataset.multiple === "true"
        );
    }

    // Returns all selected values. Array for multi-select; scalar string for single.
    get selectedValues() {
        if (this.isMultipleMode) {
            return this.hasValueOptionTarget
                ? this.valueOptionTargets
                      .filter((opt) => opt.dataset.selected === "true")
                      .map((opt) => opt.dataset.value)
                : [];
        }
        return this.hasValueTarget ? this.valueTarget.value : "";
    }

    get hasHighlightedValue() {
        return this._valuePopoverItems.some((i) =>
            i.classList.contains("highlighted"),
        );
    }

    get _valuePopoverItems() {
        return [
            ...(this.hasValueOptionTarget ? this.valueOptionTargets : []),
            ...this.operatorOptionTargets,
        ].filter((i) => !i.classList.contains("hidden"));
    }

    // Called when you selected a column
    openValuePopover(event) {
        let url = this.mensaFilterPillListOutlet.ourUrl;
        url.pathname += `/filters/${this.selectedFilterColumn}`;
        url.searchParams.append("target", this.valuePopoverTarget.id);
        if (Array.isArray(this.editingValue)) {
            this.editingValue.forEach((v) =>
                url.searchParams.append("value[]", v),
            );
        } else if (this.editingValue) {
            url.searchParams.append("value", this.editingValue);
        }
        if (this.editingOperator)
            url.searchParams.append("operator", this.editingOperator);

        get(url, {
            responseKind: "turbo-stream",
        }).then(() => {
            this.valuePopoverTarget.classList.remove("hidden");
            this.positionPopover();
            this._bindOutsideClick();
            // Restore focus to the search input so keyboard navigation (↑↓ Enter)
            // keeps working — especially after the popover is re-opened programmatically
            // following a multi-select turbo-stream re-render.
            if (this.hasMensaFilterPillListOutlet) {
                const input =
                    this.mensaFilterPillListOutlet.searchInputElement?.();
                if (input) input.focus({ preventScroll: true });
            }
        });
    }

    // Position the value popover below the search container. Uses fixed positioning
    // with viewport coordinates so it escapes any ancestor overflow clipping.
    positionPopover() {
        const container =
            this.element.closest(".mensa-table__search-container") ||
            this.element.closest(".mensa-table__search-bar");

        if (container) {
            const containerRect = container.getBoundingClientRect();
            this.valuePopoverTarget.style.top = `${containerRect.bottom + 4}px`;
        }

        if (this._pendingPill) {
            // New filter: place popover at the right edge of the pending pill,
            // directly below where the text cursor sits in the search input.
            const rect = this._pendingPill.getBoundingClientRect();
            this.valuePopoverTarget.style.left = `${rect.right}px`;
        } else if (this.anchorElement) {
            const anchor = this.anchorElement.getBoundingClientRect();
            this.valuePopoverTarget.style.left = `${anchor.left}px`;
        } else {
            const ref = this._triggerEl || this.element;
            const r = ref.getBoundingClientRect();
            this.valuePopoverTarget.style.left = `${r.left}px`;
        }
    }

    // Called when you select a column from the "dropdown"
    selectColumn(event) {
        this.filterListItemTargets.forEach((lt) => {
            let check = lt.querySelector(".check");
            check.classList.add("hidden");
        });
        let check = event.target.closest("li").querySelector(".check");
        check.classList.remove("hidden");
        this.selectedFilterColumn = event.target
            .closest("li")
            .getAttribute("data-filter-column-name");
        this.anchorElement = null;

        let label = event.target.closest("li").querySelector(".label");
        this._columnLabel = label.innerText;
        if (this.hasDescriptionTarget)
            this.descriptionTarget.innerText = `${this._columnLabel} is`;

        this._showPendingPill(this._columnLabel);
        this.hideList();
        this.openValuePopover();
    }

    // Called when an operator list item is clicked
    selectOperator(event) {
        const selected = event.currentTarget;
        this.operatorOptionTargets.forEach((opt) => {
            const check = opt.querySelector(
                ".mensa-table__add_filter__popover_container__operator__check",
            );
            if (opt === selected) {
                opt.dataset.selected = "true";
                check?.classList.remove("invisible");
            } else {
                delete opt.dataset.selected;
                check?.classList.add("invisible");
            }
        });

        const requiresValue = this.operatorRequiresValue(
            selected.dataset.operator,
        );
        if (!requiresValue) {
            if (this.hasValueTarget) this.valueTarget.value = "";
            if (this.hasValueOptionTarget) {
                this.valueOptionTargets.forEach((opt) => {
                    delete opt.dataset.selected;
                    const check = opt.querySelector(
                        ".mensa-table__add_filter__popover_container__value__check",
                    );
                    check?.classList.add("invisible");
                });
            }
        }

        // Always reflect the new operator in the description immediately.
        this._updateDescription();

        // Apply to the table immediately when a value is already selected.
        if (!requiresValue) {
            this.mensaFilterPillListOutlet.refreshFilters();
        } else if (this.isMultipleMode) {
            if (this.selectedValues.length > 0) {
                _pendingMultiReopen = {
                    column: this._selectedFilterColumn,
                    values: this.selectedValues,
                    operator: this.operator,
                };
                this.mensaFilterPillListOutlet.refreshFilters();
            }
        } else if (this.hasValueTarget && this.valueTarget.value) {
            this.mensaFilterPillListOutlet.refreshFilters();
        }
    }

    // Returns the currently selected operator, defaulting to "is"
    get operator() {
        if (!this.hasOperatorOptionTarget) return "is";
        const selected = this.operatorOptionTargets.find(
            (opt) => opt.dataset.selected === "true",
        );
        return selected?.dataset.operator ?? "is";
    }

    operatorRequiresValue(operator = this.operator) {
        const selected = this.operatorOptionTargets.find(
            (opt) => opt.dataset.operator === operator,
        );
        return selected ? selected.dataset.requiresValue !== "false" : true;
    }

    // Called via Escape — close the value popover.
    closeValuePopover() {
        this._closePopover();
    }

    // Called by the Clear link.
    reset(event) {
        if (this.hasDescriptionTarget)
            this.descriptionTarget.innerText = "Add filter";
        this.selectedFilterColumn = null;
        this._columnLabel = null;
        this._removePendingPill();
        this._closePopover();
    }

    get selectedFilterColumn() {
        return this._selectedFilterColumn;
    }

    set selectedFilterColumn(value) {
        this._selectedFilterColumn = value;
    }

    // --- private ---
    // TODO: Pull these from server

    get operatorLabel() {
        const labels = {
            is: "is",
            isnt: "is not",
            matches: "matches",
            does_not_match: "does not match",
        };
        return labels[this.operator] ?? "is";
    }

    _updateDescription() {
        if (!this._columnLabel || !this.hasDescriptionTarget) return;
        let valueLabel;
        if (this.isMultipleMode) {
            const labels = this.hasValueOptionTarget
                ? this.valueOptionTargets
                      .filter((opt) => opt.dataset.selected === "true")
                      .map((opt) => opt.dataset.label || opt.dataset.value)
                : [];
            valueLabel = labels.length > 0 ? labels.join(", ") : null;
        } else {
            const value = this.hasValueTarget ? this.valueTarget.value : "";
            if (value) {
                const option = this.hasValueOptionTarget
                    ? this.valueOptionTargets.find(
                          (opt) => opt.dataset.value === value,
                      )
                    : null;
                valueLabel = option?.dataset.label || value;
            }
        }
        if (valueLabel) {
            this.descriptionTarget.innerText = `${this._columnLabel} ${this.operatorLabel} ${valueLabel}`;
        } else {
            this.descriptionTarget.innerText = `${this._columnLabel} ${this.operatorLabel}`;
        }
    }

    _toggleValueItem(item) {
        const isSelected = item.dataset.selected === "true";
        const newState = !isSelected;
        item.dataset.selected = newState ? "true" : "";
        const checkbox = item.querySelector(
            ".mensa-table__add_filter__checkbox",
        );
        if (checkbox)
            checkbox.classList.toggle(
                "mensa-table__add_filter__checkbox--checked",
                newState,
            );
        this._updateDescription();
        // Stash reopen state before the turbo-stream destroys both this controller
        // and the filter-pill-list controller. The new add-filter instance reads
        // this in connect() and re-opens the popover after outlets are wired.
        _pendingMultiReopen = {
            column: this._selectedFilterColumn,
            values: this.selectedValues,
            operator: this.operator,
        };
        this.mensaFilterPillListOutlet.refreshFilters();
    }

    _selectValueItem(item) {
        const value = item.dataset.value;
        if (this.hasValueTarget) this.valueTarget.value = value;
        if (this.hasValueOptionTarget) {
            this.valueOptionTargets.forEach((opt) => {
                const check = opt.querySelector(
                    ".mensa-table__add_filter__popover_container__value__check",
                );
                const isSelected = opt.dataset.value === value;
                opt.dataset.selected = isSelected ? "true" : "";
                check?.classList.toggle("invisible", !isSelected);
            });
        }
        this._updateDescription();
        this._removePendingPill();
        this.mensaFilterPillListOutlet.refreshFilters();
    }

    // Position the column list below the search container, aligned to the trigger
    // element (search input or + button). Uses fixed positioning with viewport
    // coordinates so it escapes any ancestor overflow clipping.
    _positionListUnderSearchBar(triggerEl = null) {
        const container =
            this.element.closest(".mensa-table__search-container") ||
            this.element.closest(".mensa-table__search-bar");
        if (!container) return;
        const containerRect = container.getBoundingClientRect();

        this.filterListTarget.style.top = `${containerRect.bottom + 4}px`;
        this.filterListTarget.style.minWidth = "16rem";

        const anchor = triggerEl || this.element;
        const anchorRect = anchor.getBoundingClientRect();
        this.filterListTarget.style.left = `${anchorRect.left}px`;
    }

    _closePopover() {
        this._valuePopoverItems.forEach((i) =>
            i.classList.remove("highlighted"),
        );
        this.editingValue = null;
        this.editingOperator = null;
        this.anchorElement = null;
        this._removePendingPill();
        this.valuePopoverTarget.classList.add("hidden");
        this.valuePopoverTarget.style.left = "";
        this.valuePopoverTarget.style.top = "";
        this._unbindOutsideClick();
    }

    _showPendingPill(columnLabel) {
        this._removePendingPill();
        const pill = document.createElement("div");
        pill.className = "mensa-filter-pill mensa-filter-pill--pending";
        pill.innerHTML = `<div class="mensa-filter-pill__chip mensa-filter-pill__chip--pending"><span class="mensa-filter-pill__column">${this._escapeHtml(columnLabel)}</span><span class="mensa-filter-pill__operator">is</span></div>`;
        this.element.insertAdjacentElement("beforebegin", pill);
        this._pendingPill = pill;
    }

    _removePendingPill() {
        if (this._pendingPill) {
            this._pendingPill.remove();
            this._pendingPill = null;
        }
    }

    _escapeHtml(str) {
        return String(str)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;");
    }

    _bindOutsideClick() {
        this._unbindOutsideClick();
        this._outsideClickHandler = (event) => {
            if (this.element.contains(event.target)) return;
            // Keep open if user clicks within the search bar (so typing still works)
            const searchBar = this.element.closest(".mensa-table__search-bar");
            if (searchBar && searchBar.contains(event.target)) return;
            this.hideList();
            this._closePopover();
        };
        // Defer so the current click that opened the popover doesn't immediately close it
        setTimeout(() => {
            document.addEventListener("click", this._outsideClickHandler);
        }, 0);
    }

    _unbindOutsideClick() {
        if (this._outsideClickHandler) {
            document.removeEventListener("click", this._outsideClickHandler);
            this._outsideClickHandler = null;
        }
    }
}
