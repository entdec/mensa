import ApplicationController from "mensa/controllers/application_controller";
import tippy from "tippy.js";

export default class ViewsComponentController extends ApplicationController {
    static targets = ["view"];

    static outlets = ["mensa-filter-pill-list"];

    connect() {
        tippy('[data-controller="mensa-views"] [data-tippy-content]', {
            placement: "top",
            theme: "mensa",
            offset: [0, 8],
        });
    }

    select(event) {
        const selected = event.currentTarget;

        this.viewTargets.forEach((element) => {
            element === selected
                ? element.classList.add("selected")
                : element.classList.remove("selected");
        });

        // The view link reloads the table data via the turbo-frame; here we persist
        // the newly selected view (and reset filters/search/paging) so it survives
        // a page refresh.
        if (this.hasMensaFilterPillListOutlet) {
            this.mensaFilterPillListOutlet.viewSelected(
                selected.getAttribute("data-view-id") || "",
            );
        }
    }
}
