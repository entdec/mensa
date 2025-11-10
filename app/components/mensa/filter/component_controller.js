import ApplicationController from 'mensa/controllers/application_controller'

export default class FilterComponentController extends ApplicationController {
  static values = {
    columnName: String,
    operator: String,
    value: String,
  };

  connect() {
  }
}