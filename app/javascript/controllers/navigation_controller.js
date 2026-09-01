import { Controller } from "@hotwired/stimulus"

// Toggles the mobile navigation menu.
export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    this.menuTarget.classList.toggle("flex")
  }
}
