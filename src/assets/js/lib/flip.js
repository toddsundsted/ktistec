// Animates a rearrangement of elements from where they were to where
// the rearrangement leaves them.

export function flip(elements, mutate) {
  const was = elements.map((element) => element.getBoundingClientRect())

  elements.forEach((element) => {
    element.style.transition = ""
    element.style.transform = ""
  })

  mutate()

  elements.forEach((element, at) => {
    const now = element.getBoundingClientRect()
    const x = was[at].left - now.left
    const y = was[at].top - now.top
    if (!x && !y) {
      return
    }
    element.style.transition = "none"
    element.style.transform = `translate(${x}px, ${y}px)`
    requestAnimationFrame(() => {
      element.style.transition = ""
      element.style.transform = ""
    })
  })
}
