import ApplicationController from '../../../../frontend/controllers/application_controller'

import {createPopper} from "@popperjs/core"

// import { debounce } from "../../../../frontend/utils"
// import { useWindowResize } from "stimulus-use"
//
// import Sortable from "sortablejs"
import { get } from '@rails/request.js'

export default class FiltersComponentController extends ApplicationController {
  static targets = [
    'list',
  ]
  static values = {
    supportsViews: Boolean
  }

  connect () {
    super.connect()
    console.log('hi')
  }

  toggle(event) {
    console.log('toggle')
    this.listTarget.classList.toggle('hidden')
  }


}