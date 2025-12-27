# Used by "mix format"
[
  inputs: ["{mix,.formatter,.credo}.exs", "{config,examples,lib,test}/**/*.{ex,exs}"],
  import_deps: [:typedstruct, :peri, :plug],
  excludes: ["lib/atproto/**/*"],
  export: [
    locals_without_parens: [deflexicon: 1]
  ]
]
