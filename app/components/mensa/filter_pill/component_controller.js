import ApplicationController from 'mensa/controllers/application_controller'

export default class FilterPillComponentController extends ApplicationController {
  static values = {
    columnName: String,
    operator: String,
    value: String,
  };

  connect() {
  }
}