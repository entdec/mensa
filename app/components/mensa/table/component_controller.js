import ApplicationController from 'mensa/controllers/application_controller'
import { get } from '@rails/request.js'

export default class TableComponentController extends ApplicationController {
  static targets = [
    'controlBar',           // Bar with buttons
    'condenseExpandIcon',   // Icon
    'filters',              // Tabs or list of filters
    'views',                // Tabs or list of views
    'viewButtons',          // Cancel and save buttons for views
    'search',               // Search bar
    'view',                 // View contains table element
    'turboFrame'            // The turbo-frame
  ]
  static values = {
    supportsViews: Boolean
  }

  connect () {
    super.connect()
  }

  openFiltersAndSearch(event) {
    if(this.supportsViewsValue) {
      this.viewButtonsTarget.classList.remove('hidden')
      this.searchTarget.classList.remove('hidden')
      this.viewsTarget.classList.add('hidden')
      this.filtersTarget.classList.remove('hidden')
    } else {
      this.controlBarTarget.classList.add('hidden')
      this.viewButtonsTarget.classList.remove('hidden')
      this.filtersTarget.classList.remove('hidden')
    }
  }

  cancelFiltersAndSearch(event) {
    if(this.supportsViewsValue) {
      this.searchTarget.classList.add('hidden')
      this.viewButtonsTarget.classList.add('hidden')
      this.filtersTarget.classList.add('hidden')
      this.viewsTarget.classList.remove('hidden')
    } else {
      this.controlBarTarget.classList.remove('hidden')
      this.viewButtonsTarget.classList.add('hidden')
      this.filtersTarget.classList.add('hidden')
    }
  }

  saveFiltersAndSearch(event) {

  }

  condenseExpand (event) {
    if (this.viewTarget.classList.contains('mensa-table__condensed')) {
      this.viewTarget.classList.remove('mensa-table__condensed')
      this.condenseExpandIconTarget.classList.add('fa-compress')
      this.condenseExpandIconTarget.classList.remove('fa-expand')
    } else {
      this.viewTarget.classList.add('mensa-table__condensed')
      this.condenseExpandIconTarget.classList.remove('fa-compress')
      this.condenseExpandIconTarget.classList.add('fa-expand')
    }
  }

  export(event) {
    let url = this.ourUrl
    url.pathname += ".xlsx"
    get(url, {
    }).then(() => {
    })
  }
}