import ApplicationController from 'mensa/controllers/application_controller'
import { get } from '@rails/request.js'

export default class FilterPillListComponentController extends ApplicationController {
  static outlets = [
    "mensa-table",
    "mensa-filter-pill",
    "mensa-add-filter"
  ]

  static targets = [
  ]

  static values = {
    supportsViews: Boolean
  }

  connect() {
    super.connect()
  }

  refreshFilters() {
    let url = this.mensaTableOutlet.ourUrl

    let filters = url.searchParams.get('filters') || {}
    this.mensaFilterPillOutlets.forEach((filterOutlet) => {
      url.searchParams.append(`filters[${filterOutlet.columnNameValue}][value]`, filterOutlet.valueValue)
      url.searchParams.append(`filters[${filterOutlet.columnNameValue}][operator]`, filterOutlet.operatorValue)
    })

    url.searchParams.append(`filters[${this.mensaAddFilterOutlet.selectedFilterColumn}][value]`, this.mensaAddFilterOutlet.valueTarget.value)
    url.searchParams.append(`filters[${this.mensaAddFilterOutlet.selectedFilterColumn}][operator]`, 'equals')


    get(url, {
      responseKind: 'turbo-stream'
    }).then(() => {
      // FIXME: There should be a better way to do this, possibly using
      // this.mensaTableOutlet.filterListTarget.addEventListener("turbo:after-stream-render", this.unhide.bind(this)) ?
      setTimeout(() => {
        this.mensaTableOutlet.filterListTarget.classList.remove('hidden')
      }, 50)
    })
  }

  get ourUrl() {
    let url = this.mensaTableOutlet.ourUrl
    return url
  }
}