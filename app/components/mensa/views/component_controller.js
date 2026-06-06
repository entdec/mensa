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
        // Prevent the turbo-frame link navigation. viewSelected() fires a
        // turbo-stream request that updates the table view AND the filter pills
        // in a single round-trip, so we don't need the frame navigation at all.
        event.preventDefault();

        const selected = event.currentTarget;

        this.viewTargets.forEach((element) => {
            element === selected
                ? element.classList.add("selected")
                : element.classList.remove("selected");
        });

        if (this.hasMensaFilterPillListOutlet) {
            this.mensaFilterPillListOutlet.viewSelected(
                selected.getAttribute("data-view-id") || "",
            );
        }
    }
}
