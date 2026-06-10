import { application } from "mensa/controllers/application";

import LinkController from "mensa/controllers/link_controller";
application.register("mensa-link", LinkController);

import AddFilterComponentController from "mensa/components/add_filter/component_controller";
application.register("mensa-add-filter", AddFilterComponentController);

import FilterPillComponentController from "mensa/components/filter_pill/component_controller";
application.register("mensa-filter-pill", FilterPillComponentController);

import FilterPillListComponentController from "mensa/components/filter_pill_list/component_controller";
application.register(
    "mensa-filter-pill-list",
    FilterPillListComponentController,
);

import SearchComponentController from "mensa/components/search/component_controller";
application.register("mensa-search", SearchComponentController);

import TableComponentController from "mensa/components/table/component_controller";
application.register("mensa-table", TableComponentController);

import ViewsComponentController from "mensa/components/views/component_controller";
application.register("mensa-views", ViewsComponentController);

import SelectionComponentController from "mensa/components/selection/component_controller";
application.register("mensa-selection", SelectionComponentController);

import ColumnCustomizerController from "mensa/components/column_customizer/component_controller";
application.register("mensa-column-customizer", ColumnCustomizerController);

// Eager load all controllers defined in the import map under controllers/**/*_controller
// import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
// eagerLoadControllersFrom("controllers", application)

// Lazy load controllers as they appear in the DOM (remember not to preload controllers in import map!)
// import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
// lazyLoadControllersFrom("controllers", application)
