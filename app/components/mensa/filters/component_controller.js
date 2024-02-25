import ApplicationController from '../../../../frontend/controllers/application_controller'

export default class FiltersComponentController extends ApplicationController {
  static targets = [
    'list',
  ]
  static values = {
    supportsViews: Boolean
  }

  connect () {
    super.connect()
  }
}