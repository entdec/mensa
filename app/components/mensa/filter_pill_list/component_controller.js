import ApplicationController from 'mensa/controllers/application_controller'
import { get } from '@rails/request.js'

export default class FilterPillListComponentController extends ApplicationController {
  static outlets = ['mensa-table', 'mensa-filter-pill', 'mensa-add-filter']

  static targets = []

  static values = {
    supportsViews: Boolean,
    tableName: String
  }

  connect () {
    super.connect()
  }

  // The mensa-table outlet provides `ourUrl`, which we need both to apply and
  // to restore filters. Outlets connect asynchronously, so we trigger the
  // restore from the outlet-connected callback to be sure it's available.
  mensaTableOutletConnected () {
    this.restoreFilters()
  }

  // Called when a filter is added/changed. Persists the resulting filter set
  // to local storage so it survives a page refresh, then applies it.
  refreshFilters () {
    const filters = this.collectFilters()
    this.persistFilters(filters)
    this.applyFilters(filters)
  }

  // Removes every applied filter and forgets the persisted filters in local
  // storage, then reloads the table unfiltered.
  clearFilters () {
    this.persistFilters({})

    const url = this.mensaTableOutlet.ourUrl
    this.removeFilterParams(url)

    get(url, {
      responseKind: 'turbo-stream'
    })
  }

  // Strips any `filters[...]` query parameters from the given URL in place.
  removeFilterParams (url) {
    const filterKeys = []
    url.searchParams.forEach((_value, key) => {
      if (key.startsWith('filters[')) {
        filterKeys.push(key)
      }
    })
    filterKeys.forEach((key) => url.searchParams.delete(key))
  }

  // Coordinates the table's single initial load on page load.
  //
  // The table controller defers the turbo-frame load so that, when there are
  // persisted filters, we can fetch the filtered table together with its pills
  // in one request instead of first loading the unfiltered frame and then
  // re-requesting. This means a single backend call and no flash of unfiltered
  // content.
  restoreFilters () {
    const table = this.mensaTableOutlet
    const persisted = this.loadFilters()
    const hasPersisted = Object.keys(persisted).length > 0

    // Filters already on screen (e.g. a view's defaults, or a previous restore
    // after this controller was re-rendered) mean there is nothing to restore.
    const alreadyRendered = Object.keys(this.renderedFilters()).length > 0

    if (hasPersisted && !alreadyRendered && !table.frameLoadHandled) {
      // Claim the deferred frame load so the table controller does not also
      // load the unfiltered src.
      table.frameLoadHandled = true

      // Put the table chrome into the filtering state (open search bar, hide
      // the views tabs) so the restored filters don't render above the views.
      if (typeof table.showFiltersAndSearch === 'function') {
        table.showFiltersAndSearch()
      }

      // Fetch the filtered table and its pills in a single request.
      this.applyFilters(persisted)
      return
    }

    // Nothing to restore: trigger the frame's normal load. This is idempotent,
    // so re-renders after a restore (or the fallback in the table controller)
    // are a no-op.
    if (typeof table.loadFrame === 'function') {
      table.loadFrame()
    }
  }

  // Builds the request URL from a filters object and fetches the filtered
  // table via turbo-stream, updating both the filter pills and the table view.
  applyFilters (filters) {
    const url = this.mensaTableOutlet.ourUrl

    Object.entries(filters).forEach(([columnName, filter]) => {
      url.searchParams.append(
                `filters[${columnName}][value]`,
                filter.value
      )
      url.searchParams.append(
                `filters[${columnName}][operator]`,
                filter.operator
      )
    })

    get(url, {
      responseKind: 'turbo-stream'
    }).then(() => {
      // FIXME: There should be a better way to do this, possibly using
      // this.mensaTableOutlet.filterListTarget.addEventListener("turbo:after-stream-render", this.unhide.bind(this)) ?
      setTimeout(() => {
        this.mensaTableOutlet.filterListTarget.classList.remove(
          'hidden'
        )
      }, 50)
    })
  }

  // The full set of active filters: existing pills plus the one currently
  // being added (if any), keyed by column name.
  collectFilters () {
    const filters = this.renderedFilters()

    if (
      this.hasMensaAddFilterOutlet &&
            this.mensaAddFilterOutlet.selectedFilterColumn
    ) {
      filters[this.mensaAddFilterOutlet.selectedFilterColumn] = {
        value: this.mensaAddFilterOutlet.valueTarget.value,
        operator: 'equals'
      }
    }

    return filters
  }

  // Filters currently rendered as pills, read straight from the DOM so we
  // don't depend on outlet connection timing.
  renderedFilters () {
    const filters = {}

    this.element
      .querySelectorAll('[data-controller~="mensa-filter-pill"]')
      .forEach((pill) => {
        const columnName = pill.getAttribute(
          'data-mensa-filter-pill-column-name-value'
        )
        if (!columnName) return

        filters[columnName] = {
          value: pill.getAttribute(
            'data-mensa-filter-pill-value-value'
          ),
          operator: pill.getAttribute(
            'data-mensa-filter-pill-operator-value'
          )
        }
      })

    return filters
  }

  persistFilters (filters) {
    if (!this.hasStorage) return

    try {
      if (Object.keys(filters).length === 0) {
        window.localStorage.removeItem(this.storageKey)
      } else {
        window.localStorage.setItem(
          this.storageKey,
          JSON.stringify(filters)
        )
      }
    } catch (e) {
      // localStorage may be unavailable (private mode / disabled); ignore.
    }
  }

  loadFilters () {
    if (!this.hasStorage) return {}

    try {
      const raw = window.localStorage.getItem(this.storageKey)
      return raw ? JSON.parse(raw) : {}
    } catch (e) {
      return {}
    }
  }

  get hasStorage () {
    try {
      return typeof window !== 'undefined' && !!window.localStorage
    } catch (e) {
      return false
    }
  }

  get storageKey () {
    return `mensa:filters:${this.tableNameValue}`
  }

  get ourUrl () {
    const url = this.mensaTableOutlet.ourUrl
    return url
  }
}
