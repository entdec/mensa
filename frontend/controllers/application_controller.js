// application_controller.js
import { Controller } from "@hotwired/stimulus"

export default class ApplicationController extends Controller {
  connect() {
    this.element[this.identifier] = this
  }

  getController(element, identifier) {
    return this.application.getControllerForElementAndIdentifier(element, identifier)
  }

  triggerEvent(el, name, data) {
    let event
    if (typeof window.CustomEvent === "function") {
      event = new CustomEvent(name, { detail: data, cancelable: true, bubbles: true })
    } else {
      event = document.createEvent("CustomEvent")
      event.initCustomEvent(name, true, true, data)
    }
    el.dispatchEvent(event)
  }

  elementScrolled(element) {
    if (element.scrollHeight - Math.round(element.scrollTop) === element.clientHeight) {
      return true
    }
    return false
  }

  debouncedHover(element, timeout, handler) {
    var timeoutId = null;
    element.addEventListener(marker, 'mouseover',function() {
      timeoutId = setTimeout(handler, timeout);
    } );

    element.addEventListener(marker, 'mouseout',function() {
      clearTimeout(timeoutId)
    });
  }
}
