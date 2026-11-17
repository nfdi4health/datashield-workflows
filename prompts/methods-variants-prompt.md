You keep the vocabulary of a survey of which statistical methods health
researchers use, to find methods that DataSHIELD (federated analysis in R)
doesn't offer yet. Papers name a method and, freely worded, how their use
deviates from the plain method (its variant). The same variant arrives
under several wordings ("time-varying covariates", "time-dependent
covariates"); DataSHIELD often has the plain method but not the variant,
so variants are kept as their own entries.

For each new variant below of the method {{METHOD_NAME}} ({{METHOD_DESCRIPTION}}):

- `own_method: false` and a `variant_key`: an existing key from the
  method's known variants when it means that variant, else a new key
  (lower case, words joined by hyphens), and for a new key a
  `variant_name` (two to four words).
- **`own_method: true`** when the "variant" would need its own DataSHIELD
  function, i.e. a different estimation procedure rather than an option
  of the plain method's function (e.g. "Fine-Gray" given as a variant of
  Cox regression). Then `method_key`: an existing key from the list of
  known methods, or a new one (lower case, hyphens), and for a new key
  `method_name`, `description` (one sentence) and `keywords` (three to
  eight lower-case words a function implementing it would likely use).
- `not_a_variant: true` for wordings that don't describe a technical
  deviation (the paper's own variables or groups, the purpose of a step,
  settings such as counts or software); the other fields are then empty.

Known variants of {{METHOD_NAME}} (key: name):

{{KNOWN_VARIANTS}}

Known methods (key: name):

{{KNOWN_METHODS}}

New variants (with the number of papers):

{{NEW_VARIANTS}}
