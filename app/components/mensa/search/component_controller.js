import ApplicationController from 'mensa/controllers/application_controller'

import { get } from '@rails/request.js'

export default class SearchComponentController extends ApplicationController {
  static targets = [
    'resetSearchButton',
    'searchInput'
  ]
  static outlets = [
    "mensa-table"
  ]
  connect () {
    super.connect()
    this.monitorSearch()
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
    if (this.query.length < 3) {
      return
    }

    // FIXME: This doesn't prevent searching twice on enter, the turbo-frame URL doesn't change
    let url = this.ourUrl
    if(url.searchParams.get('query') === this.query) {
      return
    }

    url.searchParams.append('query', this.query)

    get(url, {
      responseKind: 'turbo-stream'
    })
  }

  get query() {
    return this.searchInputTarget.value
  }
}