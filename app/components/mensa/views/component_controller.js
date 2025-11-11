import ApplicationController from 'mensa/controllers/application_controller'

export default class ViewsComponentController extends ApplicationController {
  static targets = [
    'view',
  ]

  select(event) {
    this.viewTargets.forEach((element) => {
      (element === event.target) ? element.classList.add('selected') : element.classList.remove('selected')
    })
  }
}