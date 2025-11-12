import ApplicationController from 'mensa/controllers/application_controller'
import tippy from 'tippy.js'

export default class ViewsComponentController extends ApplicationController {
  static targets = [
    'view',
  ]

  connect() {
    tippy('[data-controller="mensa-views"] [data-tippy-content]', {
      placement: "top",
      theme: 'mensa',
      offset: [0, 8]
    });
  }

  select(event) {
    this.viewTargets.forEach((element) => {
      (element === event.target) ? element.classList.add('selected') : element.classList.remove('selected')
    })
  }
}