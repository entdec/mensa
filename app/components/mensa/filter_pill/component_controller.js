import ApplicationController from "mensa/controllers/application_controller";

export default class FilterPillComponentController extends ApplicationController {
    static outlets = ["mensa-filter-pill-list"];

    static values = {
        columnName: String,
        operator: String,
        value: String,
    };

    connect() {}

    // Re-opens the value selector for this filter's column (reusing the
    // add-filter popover), pre-selected to the current value. Choosing a new
    // value re-requests the table via the add-filter flow.
    edit(event) {
        event.preventDefault();

        if (!this.hasMensaFilterPillListOutlet) return;

        let value = this.hasValueValue ? this.valueValue : null;
        if (this.hasValueValue) {
            try {
                value = JSON.parse(value);
            } catch {}
        }

        this.mensaFilterPillListOutlet.editFilter(
            this.columnNameValue,
            value,
            this.operatorValue,
            this.element,
        );
    }

    // Removes this filter pill and re-requests the table with the remaining
    // filters. The list controller reads the active filters straight from the
    // DOM, so we drop our element first, then ask it to refresh.
    remove(event) {
        event.preventDefault();
        event.stopPropagation();

        const list = this.hasMensaFilterPillListOutlet
            ? this.mensaFilterPillListOutlet
            : null;

        this.element.remove();

        if (list) list.refreshFilters();
    }
}
