import ApplicationController from "mensa/controllers/application_controller";

export default class SearchComponentController extends ApplicationController {
    static targets = ["resetSearchButton", "searchInput"];
    static outlets = ["mensa-filter-pill-list"];

    connect() {
        super.connect();
        this.monitorSearch();
    }

    monitorSearch(event) {
        event && event.preventDefault();

        if (this.searchInputTarget.value.length >= 1) {
            this.resetSearchButtonTarget.classList.remove("hidden");
            this.searchInputTarget.focus();
        } else {
            this.resetSearchButtonTarget.classList.add("hidden");
        }
    }

    resetSearch(event) {
        event.preventDefault();

        this.searchInputTarget.value = "";
        this.searchInputTarget.focus();
        this.resetSearchButtonTarget.classList.add("hidden");

        // Re-request the table without a query (keeping any active filters) and
        // forget the persisted query. The filter pill list owns persistence and the
        // request so filters and search stay composed in a single call.
        if (this.hasMensaFilterPillListOutlet) {
            this.mensaFilterPillListOutlet.setQuery("");
        }
    }

    search(event) {
        event.preventDefault();

        if (this.query.length < 3) {
            return;
        }

        // Persist the query and re-request the table, keeping any active filters.
        if (this.hasMensaFilterPillListOutlet) {
            this.mensaFilterPillListOutlet.setQuery(this.query);
        }
    }

    get query() {
        return this.searchInputTarget.value;
    }
}
