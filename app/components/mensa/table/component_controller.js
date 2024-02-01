import ApplicationController from "../../../../frontend/controllers/application_controller"
// FIXME: Is this full path really needed?
// import { debounce } from "../../../../frontend/utils"
// import { useWindowResize } from "stimulus-use"
//
// import Sortable from "sortablejs"

export default class TableComponentController extends ApplicationController {
  static targets = [
    "condenseExpandIcon",
    "resetSearchButton",
    "searchInput"
  ]
  static values = {
    resetUrl: String,
    pager: String,
  }

  connect () {
    super.connect()

    // this.boundMonitorSearchInput = this.monitorSearchInput.bind(this)
    //
    // this.searchInputTarget.addEventListener("keydown", this.boundMonitorSearchInput)

  }

  condenseExpand(event) {
    if(this.element.classList.contains('mensa-table__condensed')) {
      this.element.classList.remove("mensa-table__condensed")
      this.condenseExpandIconTarget.classList.add("fa-compress")
      this.condenseExpandIconTarget.classList.remove("fa-expand")
    } else {
      this.element.classList.add("mensa-table__condensed")
      this.condenseExpandIconTarget.classList.remove("fa-compress")
      this.condenseExpandIconTarget.classList.add("fa-expand")
    }
  }

  monitorSearch(event) {
    if(this.searchInputTarget.value.length >= 1) {
      this.resetSearchButtonTarget.classList.remove('hidden')
    } else {
      this.resetSearchButtonTarget.classList.add('hidden')
    }
  }

  resetSearch(event) {
    this.searchInputTarget.value = ''
    this.searchInputTarget.focus()
    this.resetSearchButtonTarget.classList.add('hidden')
  }
}