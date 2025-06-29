# Used by "mix format"
[
  inputs: ["{mix,.formatter,.credo}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:typedstruct, :peri],
  export: [
    locals_without_parens: [deflexicon: 1]
  ]
]
