import ApplicationController from '../../../../frontend/controllers/application_controller'
// FIXME: Is this full path really needed?
// import { debounce } from "../../../../frontend/utils"
// import { useWindowResize } from "stimulus-use"
//
// import Sortable from "sortablejs"
import { get } from '@rails/request.js'

export default class TableComponentController extends ApplicationController {
  static targets = [
    'controlBar',
    'condenseExpandIcon',
    'resetSearchButton',
    'searchInput',
    'search',
    'filters',
    'views',
    'viewButtons'
  ]
  static values = {
    supportsViews: Boolean
  }

  connect () {
    super.connect()
    this.monitorSearch()
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
    console.log('cancel')
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

  monitorSearch (event) {
    if (this.searchInputTarget.value.length >= 1) {
      this.resetSearchButtonTarget.classList.remove('hidden')
      this.searchInputTarget.focus();
    } else {
      this.resetSearchButtonTarget.classList.add('hidden')
    }
  }

  resetSearch (event) {
    this.searchInputTarget.value = ''
    this.searchInputTarget.focus()
    this.resetSearchButtonTarget.classList.add('hidden')

    let turboFrame = this.element.closest('turbo-frame')
    let url = this.ourUrl
    url.searchParams.delete('query')

    get(url, {
      responseKind: 'turbo-stream'
    })
  }

  search (event) {
    if (this.searchInputTarget.value.length < 3) {
      return
    }
    let query = this.searchInputTarget.value

    let url = this.ourUrl
    url.searchParams.append('query', query)

    get(url, {
      responseKind: 'turbo-stream'
    })
  }

  get ourUrl() {
    let turboFrame = this.element.closest('turbo-frame')
    let url

    if (turboFrame && turboFrame.getAttribute('src')) {
      url = new URL(turboFrame.getAttribute('src'))
    } else {
      url = new URL(window.location.href)
    }
    return url
  }
}