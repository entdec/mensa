import ApplicationController from '../../../../frontend/controllers/application_controller'
import { debounce } from "@entdec/satis"


export default class AddFilterComponentController extends ApplicationController {
  static targets = [
    'columnList',
    'columnListItem',
    'description',
    'valuePopover'
  ]
  static values = {
    supportsViews: Boolean
  }

  connect () {
    super.connect()

    // This
    this.filterValueEntered = debounce(this.filterValueEntered, 500).bind(this)
  }

  toggle (event) {
    this.columnListTarget.classList.toggle('hidden')
  }

  toggleValuePopover(event) {
    this.valuePopoverTarget.classList.toggle('hidden')
  }

  selectColumn (event) {
    this.columnListItemTargets.forEach((lt) => {
      let check = lt.querySelector('.check')
      check.classList.add('hidden')
    })
    let check = event.target.closest('li').querySelector('.check')
    check.classList.remove('hidden')

    let label = event.target.closest('li').querySelector('.label')
    this.descriptionTarget.innerText = label.innerText + ': '

    this.toggle()
    this.toggleValuePopover()
  }

  filterValueEntered(event) {
    console.log("hi")
  }

}