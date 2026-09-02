# Error handling

Public APIs remain `{:ok, _} | {:error, String.t()}`. Registration errors occur before parse. `put_units/2` returns `{:ok, context} | {:error, String.t()}`.

## Registration

- Unit name: must start with a letter; letters, digits, underscore only. Derived categories also allow formula-shaped names (`m^2`, `m | s`)
- Reserved words: `and`, `or`, `not`, `null`, `true`, `false`, `yes`, `no`, `e`, `E`
- Duplicate unit name in the catalog
- Duplicate **alias** (alias collides with a unit name or another alias)
- `aliases:` entry is not a symbol (`m^2` as an alias is invalid; it is a canonical formula name)
- `default:` is an alias rather than a canonical unit name
- Duplicate category name in the catalog
- **Duplicate dimension** (second category whose dim vector matches an existing one)
- Conversion expression: parse error, not a numeric expression in `value`, or not invertible
- Formula / identity: unknown component unit; dimension does not match the category; the same category appears in both numerator and denominator after expanding derived units (`N * s | s`, `ha | m^2`, `N * s^2 | kg * m`); a formula that cancels to an empty unit (`m | m`, `m^0`)
- `default:`, when set, not among the category’s units (base **and** derived)
- Offset `to_default(0) ≠ 0` on a category with `additive: true` (default)
- Missing `default:` on a base category (`{:error, ...}`, not `KeyError`)
- Derived category missing identity: `default:` name and unit names all fail to match the base-hub product (`derived category :area needs a registered unit matching the base hubs (e.g. "m * m")`) at `Catalog.validate` / `put_units`. `identity:` without a matching unit is the same error.
- `identity:` on a base category
- `identity:` formula that does not parse to the base-hub product

## Parse

- Unit suffix with no catalog: unconsumed identifier is unexpected (`1cm`, `width + 2mm` → `unexpected 'cm'` / `unexpected 'mm'`), not a missing operand
- Suffix that is not a registered name, alias, `symbol^positive-integer` power, unbraced pipe of two atoms, or braced formula
- Negative power suffix (`1s^-2`, `5m^-1`) → `negative exponents belong in braces, for example 1 {s^-2}`
- Spaces around `^` (`5m ^ 2`) → `spaces around '^' are not a power suffix; write 5m^2`
- Unbraced product then `|` (`1 kg * m | s`) → `unexpected '|'; compound units belong in braces, for example 1 {kg * m | s}`
- Unbraced pipe continued with `* <unit>` (`3 m | s * s`, `3 m | s * h` when `h` is registered) → formula-continuation error; `* 2` stays expression multiply
- Formula suffix / `unit:` / `convert` target that cancels to nothing or repeats a category after expanding derived units (`ha | m^2`, `N * s^2 | kg * m`)
- `{` with no catalog, or `{` not after a numeric literal → `unexpected '{'`
- Unclosed `{` / invalid formula inside braces / `/` or parentheses inside braces
- Unit token after a variable name

## Validate

- Unknown variable; reserved name as variable (existing)
- Variable `category:` set but value unitless, or value unitful but no category
- Value unit not in the declared category
- `+`/`-` different categories (`cannot add length and mass`), or a number with a unit (`cannot add length and number`, `cannot subtract number from length`)
- Optional `category: :speed` when the inferred formula is not `length | time` (including decimal/boolean results) — **speed** was expected, with the inferred type (`speed was expected, got length^2`)
- `category:` with no catalog, or unknown category → **raise** (not `{:error, …}`)
- Non-additive category in binary `+ − * /` (including hub `C`, `1C + 2C`, `2 * 1C`)
- Function `units: :none` rejects unitful args (`sqrt`, `pow`, `rem`, `mod`, strings)
- Function `units: :additive` with a non-additive operand
- `min` / `max` / `between` / `clamp`: mixed **categories** (`cannot mix length and mass`), or mixed **units** of a non-additive category (`1C` vs `2F`)
- `if` branches of different types (`if branches must have the same type, got length and mass`)
- Compare unit vs number (`cannot compare length and number`); mixed **units** of a non-additive category (`1C` vs `2F`)
- `convert/2`: first arg a number (`cannot convert a number`); target unknown / wrong dim; non-additive symbol in a compound target
- `remove_unit/1`: number arg (`cannot remove unit from a number`)
- `add_unit/2`: first arg unitful (`add_unit cannot wrap a quantity that already has a unit`); second not a registered canonical name or alias (unregistered compounds like `"m | s"` rejected)

## Evaluate

- Arithmetic errors (`division by zero`), including inside a conversion
- `unit:` unknown symbol (empty/whitespace `unit:` is `unit is empty`); target formula uses unregistered symbols
- `unit:` dim mismatch: look up the **target** unit’s category → `expression should return a valid length result` (not “cannot convert speed to length”)
- `unit:` with no catalog → **raise**
- `convert/2` dim mismatch keeps `cannot convert length to mass`
- Conversion that still cannot map through the identity after attach (should not happen if `put_units` succeeded)
- Compound `unit:` / `convert` target containing a non-additive unit
- `Elex.evaluate/2` returns the same reason strings as parse/validate (`division by zero`, `unknown unit 'foo'`). It does not prefix `Evaluation error:`.

## Message style

Match existing type errors: name the units and categories (`cannot add length and mass`, `cannot add length and number`, `cannot mix length and mass`, `unknown unit 'foo'`). Without a catalog, unconsumed identifier-like tokens are `unexpected 'mm'`, not a missing operand. Root `unit:` incompatibility uses the target category (`expression should return a valid length result`). Empty `unit:` is `unit is empty`. Operator type errors use `cannot` (`an expression cannot start with '+'`, `'+' operator cannot be used on number and text`). Negative power suffixes (`1s^-2`) hint that negative exponents belong in braces. Spaced `5m ^ 2` hints to write `5m^2`. Unbraced `1 kg * m | s` hints that compound units belong in braces. `add_unit` of a quantity is `add_unit cannot wrap a quantity that already has a unit`.
