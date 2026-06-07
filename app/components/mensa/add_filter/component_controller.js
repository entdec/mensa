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
    }

    disconnect() {
        this._unbindOutsideClick();
    }

    // Called when you click add-filter
    toggle(event) {
        this.filterListTarget.classList.toggle("hidden");
    }

    // Re-opens the value popover for an already-applied filter (clicked pill),
    // pre-selected to its current value. Routes through the same popover/flow as
    // adding a brand new filter, so selecting a value re-requests the table.
    editColumn(columnName, value, anchor) {
        this.selectedFilterColumn = columnName;
        this.editingValue = value;
        this.anchorElement = anchor;

        // Resolve the human column label from the filter list so _updateDescription works.
        const item = this.filterListItemTargets.find(
            (li) => li.dataset.filterColumnName === columnName,
        );
        this._columnLabel =
            item?.querySelector(".label")?.innerText ?? columnName;

        this.openValuePopover();
    }

    // Called when you selected a column
    openValuePopover(event) {
        let url = this.mensaFilterPillListOutlet.ourUrl;
        url.pathname += `/filters/${this.selectedFilterColumn}`;
        url.searchParams.append("target", this.valuePopoverTarget.id);
        if (this.editingValue)
            url.searchParams.append("value", this.editingValue);

        get(url, {
            responseKind: "turbo-stream",
        }).then(() => {
            this.valuePopoverTarget.classList.remove("hidden");
            this.positionPopover();
            this._bindOutsideClick();
        });
    }

    // The value popover lives inside the add-filter element (its positioning
    // context). When editing an existing pill we shift it horizontally so it
    // appears under that pill instead of under the add-filter button.
    positionPopover() {
        if (this.anchorElement) {
            const base = this.element.getBoundingClientRect();
            const anchor = this.anchorElement.getBoundingClientRect();
            this.valuePopoverTarget.style.left = `${anchor.left - base.left}px`;
        } else {
            this.valuePopoverTarget.style.left = "";
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
        this.descriptionTarget.innerText = `${this._columnLabel} is`;

        this.toggle();
        this.openValuePopover();
    }

    // Called when you entered/selected a filter value — applies immediately,
    // but leaves the popover open so the user can change the operator or close
    // by clicking outside.
    filterValueEntered(event) {
        this._updateDescription();
        this.mensaFilterPillListOutlet.refreshFilters();
        event.preventDefault();
        return false;
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

    reset(event) {
        this.descriptionTarget.innerText = "Add filter";
        this.selectedFilterColumn = null;
        this._columnLabel = null;
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
        if (!this._columnLabel) return;
        const hasValue = this.hasValueTarget && this.valueTarget.value;
        if (hasValue) {
            const select = this.valueTarget;
            const valueLabel =
                select.options[select.selectedIndex]?.text ?? select.value;
            this.descriptionTarget.innerText = `${this._columnLabel} ${this.operatorLabel} ${valueLabel}`;
        } else {
            // No value chosen yet — just reflect the operator so the user can
            // see which one is active before picking a value.
            this.descriptionTarget.innerText = `${this._columnLabel} ${this.operatorLabel}`;
        }
    }

    _closePopover() {
        this.editingValue = null;
        this.anchorElement = null;
        this.valuePopoverTarget.classList.add("hidden");
        this.valuePopoverTarget.style.left = "";
        this._unbindOutsideClick();
    }

    _bindOutsideClick() {
        this._unbindOutsideClick();
        this._outsideClickHandler = (event) => {
            if (!this.element.contains(event.target)) {
                this._closePopover();
            }
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
