import { Controller } from "@hotwired/stimulus"

// Toggles the mobile navigation menu.
export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    this.menuTarget.classList.toggle("flex")
    this.element.querySelector("button").setAttribute("aria-expanded", !this.menuTarget.classList.contains("hidden"))
  }
}
