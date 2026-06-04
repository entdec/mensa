import ApplicationController from "mensa/controllers/application_controller";

export default class FilterPillComponentController extends ApplicationController {
    static outlets = ["mensa-filter-pill-list"];

    static values = {
        columnName: String,
        operator: String,
        value: String,
    };

    connect() {}

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
