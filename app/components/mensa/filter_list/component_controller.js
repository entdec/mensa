import ApplicationController from 'mensa/controllers/application_controller'

export default class FilterListComponentController extends ApplicationController {
  static targets = [
    'list',
  ]
  static values = {
    supportsViews: Boolean
  }

  connect() {
    super.connect()
  }
}