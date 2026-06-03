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
  // to restore state. Outlets connect asynchronously, so we trigger the restore
  // from the outlet-connected callback to be sure it's available.
  mensaTableOutletConnected () {
    this.restoreState()
  }

  // Called when a filter is added/changed. Persists the resulting filter set
  // (together with the current search query) to local storage so it survives a
  // page refresh, then applies it.
  refreshFilters () {
    const filters = this.collectFilters()
    const query = this.loadQuery()

    this.persistFilters(filters)
    this.applyState(filters, query)
  }

  // Called by the search controller when the query is submitted or reset. Keeps
  // any active filters in place while updating the persisted query.
  setQuery (query) {
    this.persistQuery(query)
    this.refreshFilters()
  }

  // Removes every applied filter and the search query, forgets them in local
  // storage and clears the search field, then reloads the table unfiltered.
  clearFiltersAndSearch () {
    this.persistFilters({})
    this.persistQuery('')
    this.setSearchField('')

    this.requestState({}, '')
  }

  // Restores persisted filters and search query on initial page load.
  //
  // The table controller defers the turbo-frame load so that, when there is
  // persisted state, we can fetch the filtered/searched table together with its
  // pills in a single request instead of first loading the unfiltered frame and
  // then re-requesting. This means a single backend call and no flash of
  // unfiltered content.
  restoreState () {
    const table = this.mensaTableOutlet
    const filters = this.loadFilters()
    const query = this.loadQuery()
    const hasState = Object.keys(filters).length > 0 || query.length > 0

    // Filters already on screen (e.g. a view's defaults, or a previous restore
    // after this controller was re-rendered) mean there is nothing to restore.
    const alreadyRendered = Object.keys(this.renderedFilters()).length > 0

    if (hasState && !alreadyRendered && !table.frameLoadHandled) {
      // Claim the deferred frame load so the table controller does not also
      // load the unfiltered src.
      table.frameLoadHandled = true

      // Restore the search field and put the table chrome into the filtering
      // state (open search bar, hide the views tabs) so the restored state
      // doesn't render above the views.
      this.setSearchField(query)
      if (typeof table.showFiltersAndSearch === 'function') {
        table.showFiltersAndSearch()
      }

      // Fetch the filtered/searched table and its pills in a single request.
      this.applyState(filters, query)
      return
    }

    // Nothing to restore: trigger the frame's normal load. This is idempotent,
    // so re-renders after a restore (or the fallback in the table controller)
    // are a no-op.
    if (typeof table.loadFrame === 'function') {
      table.loadFrame()
    }
  }

  // Builds the request URL from the given filters and query and fetches the
  // table via turbo-stream, updating both the filter pills and the table view.
  requestState (filters, query) {
    const url = this.mensaTableOutlet.ourUrl

    this.removeFilterParams(url)
    url.searchParams.delete('query')
    url.searchParams.delete('page')

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

    if (query) {
      url.searchParams.set('query', query)
    }

    return get(url, {
      responseKind: 'turbo-stream'
    })
  }

  // Same as requestState, but also reveals the filter bar once the response has
  // rendered (used when applying state from a user action or a restore).
  applyState (filters, query) {
    this.requestState(filters, query).then(() => {
      // FIXME: There should be a better way to do this, possibly using
      // this.mensaTableOutlet.filterListTarget.addEventListener("turbo:after-stream-render", this.unhide.bind(this)) ?
      setTimeout(() => {
        this.mensaTableOutlet.filterListTarget.classList.remove(
          'hidden'
        )
      }, 50)
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

  // Reflects the persisted query in the search field (value + reset button).
  setSearchField (query) {
    const input = this.searchInputElement()
    if (input) {
      input.value = query || ''
    }

    const button = this.resetSearchButtonElement()
    if (button) {
      button.classList.toggle('hidden', !(query && query.length > 0))
    }
  }

  searchInputElement () {
    const root = this.element.closest('.mensa-table')
    return root
      ? root.querySelector('[data-mensa-search-target="searchInput"]')
      : null
  }

  resetSearchButtonElement () {
    const root = this.element.closest('.mensa-table')
    return root
      ? root.querySelector(
        '[data-mensa-search-target="resetSearchButton"]'
      )
      : null
  }

  persistFilters (filters) {
    if (!this.hasStorage) return

    try {
      if (Object.keys(filters).length === 0) {
        window.localStorage.removeItem(this.filtersStorageKey)
      } else {
        window.localStorage.setItem(
          this.filtersStorageKey,
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
      const raw = window.localStorage.getItem(this.filtersStorageKey)
      return raw ? JSON.parse(raw) : {}
    } catch (e) {
      return {}
    }
  }

  persistQuery (query) {
    if (!this.hasStorage) return

    try {
      if (query && query.length > 0) {
        window.localStorage.setItem(this.searchStorageKey, query)
      } else {
        window.localStorage.removeItem(this.searchStorageKey)
      }
    } catch (e) {
      // localStorage may be unavailable (private mode / disabled); ignore.
    }
  }

  loadQuery () {
    if (!this.hasStorage) return ''

    try {
      return window.localStorage.getItem(this.searchStorageKey) || ''
    } catch (e) {
      return ''
    }
  }

  get hasStorage () {
    try {
      return typeof window !== 'undefined' && !!window.localStorage
    } catch (e) {
      return false
    }
  }

  get filtersStorageKey () {
    return `mensa:filters:${this.tableNameValue}`
  }

  get searchStorageKey () {
    return `mensa:search:${this.tableNameValue}`
  }

  get ourUrl () {
    const url = this.mensaTableOutlet.ourUrl
    return url
  }
}
