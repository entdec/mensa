import ApplicationController from '../../../../frontend/controllers/application_controller'
import { debounce } from '@entdec/satis'
import { get } from '@rails/request.js'

export default class AddFilterComponentController extends ApplicationController {
  static outlets = [
    "mensa-table"
  ]
  static targets = [
    'filterList',     // all filters
    'filterListItem', // individual filters
    'description',    // contains the filter description in the "tab"
    'valuePopover'    // contains the filter-value
  ]
  static values = {
    supportsViews: Boolean
  }

  connect () {
    super.connect()

    // this.filterValueEntered = debounce(this.filterValueEntered, 500).bind(this)
    // this.filterValueEntered = this.filterValueEntered.bind(this)
    this.selectedFilterColumn = null
  }

  // Called when you click add-filter
  toggle (event) {
    this.filterListTarget.classList.toggle('hidden')
  }

  // Called when you selected a column
  openValuePopover (event) {
    let url = this.ourUrl
    url.pathname += `/filters/${this.selectedFilterColumn}`
    url.searchParams.append('target', this.valuePopoverTarget.id)

    get(url, {
      responseKind: 'turbo-stream'
    }).then(() => {
      this.valuePopoverTarget.classList.remove('hidden')
    })
  }

  // Called when you select a column from the "dropdown"
  selectColumn (event) {
    this.filterListItemTargets.forEach((lt) => {
      let check = lt.querySelector('.check')
      check.classList.add('hidden')
    })
    let check = event.target.closest('li').querySelector('.check')
    check.classList.remove('hidden')
    this.selectedFilterColumn = event.target.closest('li').getAttribute('data-filter-column-name')

    let label = event.target.closest('li').querySelector('.label')
    this.descriptionTarget.innerText = label.innerText + ': '

    this.toggle()
    this.openValuePopover()
  }

  // Called when you entered/selected a filter value
  filterValueEntered (event) {
    this.valuePopoverTarget.classList.add('hidden')

    let url = this.ourUrl

    let filters = url.searchParams.get('filters') || {}
    // FIXME: Needs better way of getting value
    url.searchParams.append(`filters[${this.selectedFilterColumn}]`, event.target.value)

    get(url, {
      responseKind: 'turbo-stream'
    }).then(() => {
      // FIXME: There should be a better way to do this, possibly using
      // this.mensaTableOutlet.filtersTarget.addEventListener("turbo:after-stream-render", this.unhide.bind(this)) ?
      setTimeout(() => {
        this.mensaTableOutlet.filtersTarget.classList.remove('hidden')
      }, 50)
    })
  }
}