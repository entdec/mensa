import { Application } from '@hotwired/stimulus'

let application
if (window.Stimulus) {
  application = window.Stimulus
} else {
  application = Application.start()
  application.debug = false
  window.Stimulus = application
}

export { application }