## Working as an agent

You can try your code before you answer. Write it to a file in `.agent/`
(e.g. `.agent/draft.R`) and run:

    Rscript {{HELPER}} .agent/draft.R

That runs the DSLite test setup with mock data (logged in, connections in
`{{CONNECTIONS}}`), the scripts before this step, and then your file, and
prints each statement with its output or the error. It is the only command
you can run, and it has no network. A statement calling a function DSLite
can't run (listed above) is skipped, with a note, and so are later
statements using its result: that code can't be tried here, only on the
real servers.

- Use it to check what you aren't sure of (a function's result, a column
  name, a class), then keep only the code the step needs in your answer.
  Looking is for you; the script the analyst gets has no inspection calls.
- Run your final code once before you answer, and fix it until it runs.
- The mock data is small and synthetic: check that the code works, not
  the numbers.
- You can read the project's files except the real login file and
  `.Renviron`. Don't try to read data files.
- Answer with the structured output (the same fields as described above).
