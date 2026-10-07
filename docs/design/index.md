# Design docs

Initiative-level designs for Elex. Each subdirectory has its own `index.md`.

| Design | Status | Summary |
|---|---|---|
| [units/](units/index.md) | complete | Opt-in catalogs, quantities, `|` formulas, compound literal suffixes |
| [unitless-zero/](unitless-zero/index.md) | complete | Literal `0` next to additive quantities in comparisons and `:point` functions |
| [autocomplete/](autocomplete/index.md) | complete | `Elex.autocomplete/4` — syntactic completions for incomplete expressions |
| [percent/](percent/index.md) | complete | `%` suffix for percent values |
| [denominator-scale/](denominator-scale/index.md) | in progress | implementation review |
| [inverse-conversion/](inverse-conversion/index.md) | complete | Reciprocal conversion between an inverse formula and the category default |
| [not-derivable/](not-derivable/index.md) | complete | `derivable: false` so litre stays volume inside `volume \| length` |

Start at the linked `index.md` for decisions and user flows.
