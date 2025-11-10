import { application } from "mensa/controllers/application"

// import AddFilterComponentController from 'components/add_filter/component_controller';
// application.register('mensa-add-filter', AddFilterComponentController)

import AddFilterComponentController from "mensa/components/add_filter/component_controller";
application.register("mensa-add-filter", AddFilterComponentController);

import FilterComponentController from "mensa/components/filter/component_controller";
application.register("mensa-filter", FilterComponentController);

import FilterListComponentController from "mensa/components/filter_list/component_controller";
application.register("mensa-filter-list", FilterListComponentController);

import SearchComponentController from "mensa/components/search/component_controller";
application.register("mensa-search", SearchComponentController);

import TableComponentController from 'mensa/components/table/component_controller'
application.register("mensa-table", TableComponentController);

// Eager load all controllers defined in the import map under controllers/**/*_controller
// import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
// eagerLoadControllersFrom("controllers", application)

// Lazy load controllers as they appear in the DOM (remember not to preload controllers in import map!)
// import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
// lazyLoadControllersFrom("controllers", application)
