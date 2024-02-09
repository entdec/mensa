import ApplicationController from '../../../../frontend/controllers/application_controller'

export default class TableComponentController extends ApplicationController {
  static targets = [
    'controlBar',
    'condenseExpandIcon',
    'filters',
    'views',
    'viewButtons',
    'search'
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
    if (this.element.classList.contains('mensa-table__condensed')) {
      this.element.classList.remove('mensa-table__condensed')
      this.condenseExpandIconTarget.classList.add('fa-compress')
      this.condenseExpandIconTarget.classList.remove('fa-expand')
    } else {
      this.element.classList.add('mensa-table__condensed')
      this.condenseExpandIconTarget.classList.remove('fa-compress')
      this.condenseExpandIconTarget.classList.add('fa-expand')
    }
  }
}