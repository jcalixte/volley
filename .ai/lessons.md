# Lessons

- Vue's default `whitespace: "condense"` drops a leading space inside an element: `<span> {{ x }}</span>` renders with no space. Separate inline pieces with flex `gap-*`, not literal spaces in the template.
