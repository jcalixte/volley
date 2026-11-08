# Redesign of the controls above the tabs

- [x] Team picker: 44px trigger, team icon, colour dots, season match count, "N matchs" in menu, 44px menu rows
- [x] Agenda menu in its own component (AgendaMenu.vue): 44px button, full width on mobile, icon per option, team dots in title
- [x] Copy option: check icon + aria-live "Lien copié"
- [x] Hint text /60 to /70 for contrast
- [x] TablerIcon.vue for path-only icons

## Review
vitest 85/85, vue-tsc, oxlint, oxfmt, vite build pass. Not tested in browser.
