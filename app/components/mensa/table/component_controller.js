import ApplicationController from "mensa/controllers/application_controller";
import { get } from "@rails/request.js";

export default class TableComponentController extends ApplicationController {
  static outlets = ["mensa-filter-pill"]

  static targets = [
    "controlBar", // Bar with buttons
    "condenseExpandIcon", // Icon
    "filterList", // Tabs or list of filters
    "views", // Tabs or list of views
    "viewButtons", // Cancel and save buttons for views
    "search", // Search bar
    "view", // View contains table element
    "turboFrame", // The turbo-frame
  ];
  static values = {
    supportsViews: Boolean,
  };

  connect() {
    super.connect();

    // FIXME: Workaround for https://github.com/hotwired/turbo/issues/886
    this.turboFrameTarget.removeAttribute('loading');
  }

  openFiltersAndSearch(event) {
    event.preventDefault();

    if (this.supportsViewsValue) {
      this.viewButtonsTarget.classList.remove("hidden");
      this.searchTarget.classList.remove("hidden");
      this.viewsTarget.classList.add("hidden");
      this.filterListTarget.classList.remove("hidden");
    } else {
      this.controlBarTarget.classList.add("hidden");
      this.viewButtonsTarget.classList.remove("hidden");
      this.filterListTarget.classList.remove("hidden");
    }
  }

  cancelFiltersAndSearch(event) {
    event.preventDefault();

    if (this.supportsViewsValue) {
      this.searchTarget.classList.add("hidden");
      this.viewButtonsTarget.classList.add("hidden");
      this.filterListTarget.classList.add("hidden");
      this.viewsTarget.classList.remove("hidden");
    } else {
      this.controlBarTarget.classList.remove("hidden");
      this.viewButtonsTarget.classList.add("hidden");
      this.filterListTarget.classList.add("hidden");
    }
  }

  saveFiltersAndSearch(event) {
    event.preventDefault();
  }

  condenseExpand(event) {
    event.preventDefault();

    if (this.viewTarget.classList.contains("mensa-table__condensed")) {
      this.viewTarget.classList.remove("mensa-table__condensed");
      this.condenseExpandIconTarget.classList.add("fa-compress");
      this.condenseExpandIconTarget.classList.remove("fa-expand");
    } else {
      this.viewTarget.classList.add("mensa-table__condensed");
      this.condenseExpandIconTarget.classList.remove("fa-compress");
      this.condenseExpandIconTarget.classList.add("fa-expand");
    }
  }

  export(event) {
    event.preventDefault();

    let url = this.ourUrl;
    url.pathname += ".xlsx";
    get(url, {}).then(() => { });
  }

  get ourUrl() {
    let url

    if (this.turboFrameTarget?.getAttribute('src')) {
      url = new URL(this.turboFrameTarget.getAttribute('src'))
    } else {
      url = new URL(window.location.href)
    }
    return url
  }
}
