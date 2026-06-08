import ApplicationController from "mensa/controllers/application_controller";
// import { debounce } from '@entdec/satis'
import { get } from "@rails/request.js";

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
    }

    disconnect() {
        this._unbindOutsideClick();
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
        this.filterListItemTargets.forEach((i) => i.classList.remove("highlighted"));
        this.filterListTarget.classList.add("hidden");
        this._unbindOutsideClick();
    }

    // Filters the visible column items to those matching `query`.
    filterColumns(query) {
        const q = (query || "").toLowerCase();
        this.filterListItemTargets.forEach((item) => {
            const label = item.querySelector(".label")?.textContent?.toLowerCase() || "";
            item.classList.toggle("hidden", q.length > 0 && !label.includes(q));
        });
    }

    get visibleColumnCount() {
        return this.filterListItemTargets.filter((i) => !i.classList.contains("hidden")).length;
    }

    get hasHighlightedColumn() {
        return !!this.filterListItemTargets.find((i) => i.classList.contains("highlighted"));
    }

    confirmHighlightedColumn() {
        const item = this.filterListItemTargets.find((i) => i.classList.contains("highlighted"));
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
        const items = this.filterListItemTargets.filter((i) => !i.classList.contains("hidden"));
        if (!items.length) return;
        const current = items.findIndex((i) => i.classList.contains("highlighted"));
        const next = current < items.length - 1 ? current + 1 : 0;
        items.forEach((i) => i.classList.remove("highlighted"));
        items[next].classList.add("highlighted");
        items[next].scrollIntoView({ block: "nearest" });
    }

    highlightPrev() {
        const items = this.filterListItemTargets.filter((i) => !i.classList.contains("hidden"));
        if (!items.length) return;
        const current = items.findIndex((i) => i.classList.contains("highlighted"));
        const prev = current > 0 ? current - 1 : items.length - 1;
        items.forEach((i) => i.classList.remove("highlighted"));
        items[prev].classList.add("highlighted");
        items[prev].scrollIntoView({ block: "nearest" });
    }

    // Mouse hover on column list items — keeps highlight in sync with cursor
    columnItemHovered(event) {
        this.filterListItemTargets.forEach((i) => i.classList.remove("highlighted"));
        event.currentTarget.classList.add("highlighted");
    }

    // Keyboard navigation: move highlight down/up in the value popover (values + operators)
    highlightNextValue() {
        const items = this._valuePopoverItems;
        if (!items.length) return;
        const current = items.findIndex((i) => i.classList.contains("highlighted"));
        const next = current < items.length - 1 ? current + 1 : 0;
        items.forEach((i) => i.classList.remove("highlighted"));
        items[next].classList.add("highlighted");
        items[next].scrollIntoView({ block: "nearest" });
    }

    highlightPrevValue() {
        const items = this._valuePopoverItems;
        if (!items.length) return;
        const current = items.findIndex((i) => i.classList.contains("highlighted"));
        const prev = current > 0 ? current - 1 : items.length - 1;
        items.forEach((i) => i.classList.remove("highlighted"));
        items[prev].classList.add("highlighted");
        items[prev].scrollIntoView({ block: "nearest" });
    }

    // Mouse hover on value/operator items — keeps highlight in sync with cursor
    highlightItem(event) {
        this._valuePopoverItems.forEach((i) => i.classList.remove("highlighted"));
        event.currentTarget.classList.add("highlighted");
    }

    // Confirm the highlighted (or pre-selected) item in the value popover via Enter
    confirmHighlightedValue() {
        let item = this._valuePopoverItems.find((i) => i.classList.contains("highlighted"));
        // Fall back to pre-selected value option if nothing is keyboard-highlighted
        if (!item && this.hasValueOptionTarget) {
            item = this.valueOptionTargets.find((opt) => opt.dataset.selected === "true");
        }
        if (!item) return;
        if (this.hasValueOptionTarget && this.valueOptionTargets.includes(item)) {
            this._selectValueItem(item);
        } else {
            item.click();
        }
    }

    // Click handler for custom value list items
    selectValue(event) {
        this._selectValueItem(event.currentTarget);
    }

    get isValuePopoverOpen() {
        return this.hasValuePopoverTarget && !this.valuePopoverTarget.classList.contains("hidden");
    }

    get hasHighlightedValue() {
        return this._valuePopoverItems.some((i) => i.classList.contains("highlighted"));
    }

    get _valuePopoverItems() {
        return [
            ...(this.hasValueOptionTarget ? this.valueOptionTargets : []),
            ...this.operatorOptionTargets,
        ];
    }

    // Called when you selected a column
    openValuePopover(event) {
        let url = this.mensaFilterPillListOutlet.ourUrl;
        url.pathname += `/filters/${this.selectedFilterColumn}`;
        url.searchParams.append("target", this.valuePopoverTarget.id);
        if (this.editingValue)
            url.searchParams.append("value", this.editingValue);
        if (this.editingOperator)
            url.searchParams.append("operator", this.editingOperator);

        get(url, {
            responseKind: "turbo-stream",
        }).then(() => {
            this.valuePopoverTarget.classList.remove("hidden");
            this.positionPopover();
            this._bindOutsideClick();
        });
    }

    // Position the value popover below the search container. When editing an
    // existing pill the left edge is aligned to that pill; otherwise it aligns
    // to the left edge of the search container.
    positionPopover() {
        const container =
            this.element.closest(".mensa-table__search-container") ||
            this.element.closest(".mensa-table__search-bar");
        const base = this.element.getBoundingClientRect();

        if (container) {
            const containerRect = container.getBoundingClientRect();
            this.valuePopoverTarget.style.top = `${containerRect.bottom - base.top + 4}px`;
        }

        if (this.anchorElement) {
            const anchor = this.anchorElement.getBoundingClientRect();
            this.valuePopoverTarget.style.left = `${anchor.left - base.left}px`;
        } else {
            // Align to the trigger element (search input or + button) when available,
            // otherwise fall back to the add-filter element's own position.
            const ref = this._triggerEl || this.element;
            const r = ref.getBoundingClientRect();
            this.valuePopoverTarget.style.left = `${r.left - base.left}px`;
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
        if (this.hasDescriptionTarget) this.descriptionTarget.innerText = `${this._columnLabel} is`;

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

        // Always reflect the new operator in the description immediately.
        this._updateDescription();

        // Apply to the table immediately when a value is already selected.
        if (this.hasValueTarget && this.valueTarget.value) {
            this.mensaFilterPillListOutlet.refreshFilters();
        }
    }

    // Returns the currently selected operator, defaulting to "equals"
    get operator() {
        if (!this.hasOperatorOptionTarget) return "equals";
        const selected = this.operatorOptionTargets.find(
            (opt) => opt.dataset.selected === "true",
        );
        return selected?.dataset.operator ?? "equals";
    }

    closeValuePopover() {
        this._closePopover();
    }

    reset(event) {
        if (this.hasDescriptionTarget) this.descriptionTarget.innerText = "Add filter";
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

    get operatorLabel() {
        const labels = {
            equals: "is",
            not_equals: "is not",
            matches: "contains",
        };
        return labels[this.operator] ?? "is";
    }

    _updateDescription() {
        if (!this._columnLabel || !this.hasDescriptionTarget) return;
        const value = this.hasValueTarget ? this.valueTarget.value : "";
        if (value) {
            const option = this.hasValueOptionTarget
                ? this.valueOptionTargets.find((opt) => opt.dataset.value === value)
                : null;
            const valueLabel = option?.dataset.label || value;
            this.descriptionTarget.innerText = `${this._columnLabel} ${this.operatorLabel} ${valueLabel}`;
        } else {
            this.descriptionTarget.innerText = `${this._columnLabel} ${this.operatorLabel}`;
        }
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
    // element (search input or + button) so it appears under the cursor.
    _positionListUnderSearchBar(triggerEl = null) {
        const container =
            this.element.closest(".mensa-table__search-container") ||
            this.element.closest(".mensa-table__search-bar");
        if (!container) return;
        const containerRect = container.getBoundingClientRect();
        const baseRect = this.element.getBoundingClientRect();

        this.filterListTarget.style.top = `${containerRect.bottom - baseRect.top + 4}px`;
        this.filterListTarget.style.minWidth = "16rem";

        const anchor = triggerEl || this.element;
        const anchorRect = anchor.getBoundingClientRect();
        this.filterListTarget.style.left = `${anchorRect.left - baseRect.left}px`;
    }

    _closePopover() {
        this._valuePopoverItems.forEach((i) => i.classList.remove("highlighted"));
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
