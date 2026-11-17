You keep the vocabulary of a survey of which statistical methods health
researchers use, to find methods that DataSHIELD (federated analysis in R)
doesn't offer yet. Another model read the papers and wrote down each
method's name freely, so the same method arrives under several names
("Fisher exact test", "Fisher's exact test"), and some names are a method
with a variant ("one-way ANOVA" = ANOVA, variant one-way; "stratified Cox
regression" = Cox regression, variant stratified).

For each new name below, say which method it is:

- `method_key`: an existing key from the list of known methods when the
  name means that method, else a new key: lower case, words joined by
  hyphens, the method's usual name ("fishers-exact-test",
  "competing-risks-regression"). Several new names meaning the same new
  method get the same new key.
- `implied_variant`: when the name itself carries a variant of the method
  ("one-way" in "one-way ANOVA", "stratified" in "stratified Cox
  regression"), in two to four words; else `""`.
- **When a variant is a method of its own:** when it would need its own
  DataSHIELD function, i.e. a different estimation procedure, not an
  option of the plain method's function. Fine-Gray competing risks
  regression is its own method, not Cox regression with a variant; Cox
  regression with time-varying covariates is a variant. Multivariable or
  adjusted versions are the plain method.
- For a new key: `method_name` (its usual name, e.g. "Fisher's exact
  test"), `description` (one plain sentence on what it does), and
  `keywords`: three to eight lower-case words or short phrases that a
  function implementing it would likely use in its name or documentation
  (e.g. for Cox regression: "cox", "proportional hazards", "survival",
  "hazard", "coxph"). For an existing key leave these three empty.
- `not_a_method: true` for names that aren't a statistical analysis method
  (a study design, a measurement, software, "descriptive statistics" as
  such, "statistical significance"); the other fields are then empty.

Known methods (key: name):

{{KNOWN_METHODS}}

New names (with the number of papers using them and some variants they
were given):

{{NEW_NAMES}}
