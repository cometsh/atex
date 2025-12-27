# Used by "mix format"
[
  inputs:
    Enum.flat_map(
      ["{mix,.formatter,.credo}.exs", "{config,examples,lib,test}/**/*.{ex,exs}"],
      &Path.wildcard(&1, match_dot: true)
    ) -- Path.wildcard("lib/atproto/**/*.ex"),
  import_deps: [:typedstruct, :peri, :plug],
  # excludes: ["lib/atproto/**/*.ex"],
  export: [
    locals_without_parens: [deflexicon: 1]
  ]
]
