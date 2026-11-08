import { mount } from "@vue/test-utils"
import { afterEach, describe, expect, it } from "vitest"
import ThemeToggle from "./ThemeToggle.vue"

afterEach(() => {
  localStorage.clear()
  delete document.documentElement.dataset.theme
})

function button(wrapper: ReturnType<typeof mount>, label: string) {
  const found = wrapper.findAll("button").find((b) => b.text() === label)
  if (!found) throw new Error(`no ${label} button`)
  return found
}

describe("ThemeToggle", () => {
  it("follows the system when nothing is stored", () => {
    const wrapper = mount(ThemeToggle)
    expect(button(wrapper, "Auto").attributes("aria-pressed")).toBe("true")
  })

  it("forces a theme and remembers it", async () => {
    const wrapper = mount(ThemeToggle)

    await button(wrapper, "Sombre").trigger("click")
    expect(document.documentElement.dataset.theme).toBe("dark")
    expect(localStorage.getItem("theme")).toBe("dark")
    expect(button(wrapper, "Sombre").attributes("aria-pressed")).toBe("true")
    expect(button(wrapper, "Auto").attributes("aria-pressed")).toBe("false")
  })

  it("goes back to the system theme on Auto", async () => {
    localStorage.setItem("theme", "light")
    document.documentElement.dataset.theme = "light"
    const wrapper = mount(ThemeToggle)
    expect(button(wrapper, "Clair").attributes("aria-pressed")).toBe("true")

    await button(wrapper, "Auto").trigger("click")
    expect(document.documentElement.dataset.theme).toBeUndefined()
    expect(localStorage.getItem("theme")).toBeNull()
  })
})
