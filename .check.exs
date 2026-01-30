[
  tools: [
    {:compiler, true},
    {:formatter, true},
    {:unused_deps, true},
    {:credo, true},
    {:markdown,
     command: "npx prettier **/*.md --log-level warn",
     fix: "npx prettier **/*.md --write --log-level warn"},
    {:ex_unit, true}
  ]
]
