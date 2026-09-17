import { Controller } from "@hotwired/stimulus"

// Keeps the automatic handicap preview and selectable overrides in sync with
// the currently selected players.
export default class extends Controller {
  static targets = ["home", "away", "handicap"]

  connect() {
    this.update()
  }

  update() {
    const maxHandicap = this.defaultHandicap()

    this.handicapTarget.options[0].text = `auto (${maxHandicap})`

    for (const option of Array.from(this.handicapTarget.options).slice(1)) {
      option.disabled = Number(option.value) > maxHandicap

      if (option.disabled && option.selected) {
        this.handicapTarget.value = ""
      }
    }
  }

  defaultHandicap() {
    const homeRating = this.selectedRating(this.homeTarget)
    const awayRating = this.selectedRating(this.awayTarget)

    if (homeRating == null || awayRating == null) {
      return 0
    }

    return Math.max(0, Math.min(9, Math.ceil((Math.abs(homeRating - awayRating) - 350) / 100)))
  }

  selectedRating(select) {
    const rating = select.selectedOptions[0]?.dataset.rating

    return rating == null || rating === "" ? null : Number(rating)
  }
}
