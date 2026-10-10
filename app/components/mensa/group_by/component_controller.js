import ApplicationController from "mensa/controllers/application_controller";

// The group-by popover in the control bar. The choice is stored in
// localStorage (like order and filters) and sent along by the filter pill
// list when it requests the table; a blank group_by or an empty aggregates
// object means "explicitly none", so it overrides the view's default.
export default class GroupByController extends ApplicationController {
    static outlets = ["mensa-table"];
    static targets = ["button", "popover", "groupOption", "aggregates", "aggregateSelect"];
    static values = { storageKey: String, groupBy: String, aggregates: Object };

    connect() {
        super.connect();
        this._outsideClickHandler = null;

        const groupBy = this._readStorage(this.groupByStorageKey);
        if (groupBy !== null) this.groupByValue = groupBy;
        const aggregates = this._readJson(this.aggregatesStorageKey);
        if (aggregates !== null) this.aggregatesValue = aggregates;
        this._render();
    }

    disconnect() {
        this._unbindOutsideClick();
    }

    toggle() {
        if (this.popoverTarget.classList.contains("hidden")) {
            this.popoverTarget.classList.remove("hidden");
            this._positionPopover();
            this._bindOutsideClick();
        } else {
            this._close();
        }
    }

    selectGroup(event) {
        this.groupByValue = event.currentTarget.dataset.columnName || "";
        this._writeStorage(this.groupByStorageKey, this.groupByValue);
        this._render();
        this._reload();
    }

    selectAggregate(event) {
        const aggregates = { ...this.aggregatesValue };
        const column = event.currentTarget.dataset.columnName;
        if (event.currentTarget.value) {
            aggregates[column] = event.currentTarget.value;
        } else {
            delete aggregates[column];
        }
        this.aggregatesValue = aggregates;
        this._writeStorage(this.aggregatesStorageKey, JSON.stringify(aggregates));
        this._render();
        this._reload();
    }

    // Called by the table controller with the state the server rendered,
    // e.g. after selecting a view or resetting.
    sync(groupBy, aggregates) {
        this.groupByValue = groupBy || "";
        this.aggregatesValue = aggregates || {};
        this._render();
    }

    // --- private ---

    _render() {
        this.groupOptionTargets.forEach((option) => {
            option.setAttribute(
                "aria-checked",
                ((option.dataset.columnName || "") === this.groupByValue).toString(),
            );
        });
        this.aggregateSelectTargets.forEach((select) => {
            select.value = this.aggregatesValue[select.dataset.columnName] || "";
        });
        if (this.hasAggregatesTarget) {
            this.aggregatesTarget.setAttribute(
                "aria-disabled",
                (this.groupByValue === "").toString(),
            );
        }
        if (this.hasButtonTarget) {
            this.buttonTarget.setAttribute(
                "aria-pressed",
                (this.groupByValue !== "").toString(),
            );
        }
    }

    _reload() {
        const list = this.hasMensaTableOutlet
            ? this.mensaTableOutlet.mensaFilterPillListOutlet
            : null;
        if (list) list.refreshFilters();
    }

    _close() {
        this.popoverTarget.classList.add("hidden");
        this._unbindOutsideClick();
    }

    _positionPopover() {
        const rect = this.buttonTarget.getBoundingClientRect();
        const gap = 4;
        const viewportPadding = 16;
        const maxHeight = Math.min(
            384,
            window.innerHeight - rect.bottom - gap - viewportPadding,
        );

        this.popoverTarget.style.top = `${rect.bottom + gap}px`;
        this.popoverTarget.style.right = `${window.innerWidth - rect.right}px`;
        this.popoverTarget.style.left = "auto";
        this.popoverTarget.style.maxHeight = `${Math.max(maxHeight, 160)}px`;
    }

    _bindOutsideClick() {
        this._unbindOutsideClick();
        this._outsideClickHandler = (event) => {
            if (!this.element.contains(event.target)) this._close();
        };
        // Defer so the opening click doesn't immediately close the popover.
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

    get groupByStorageKey() {
        return `mensa:group_by:${this.storageKeyValue}`;
    }

    get aggregatesStorageKey() {
        return `mensa:aggregates:${this.storageKeyValue}`;
    }

    _readJson(key) {
        const raw = this._readStorage(key);
        if (raw === null) return null;
        try {
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    _writeStorage(key, value) {
        try {
            window.localStorage.setItem(key, value);
        } catch (e) {}
    }

    _readStorage(key) {
        try {
            return window.localStorage.getItem(key);
        } catch (e) {
            return null;
        }
    }
}
