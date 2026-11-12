#!/usr/bin/env bash
# Self-test of datashield-analysis-suggest.yml: builds a dsAnalysis project
# in the workspace from the templates of the dsAnalysis checkout
# (.dsanalysis, the same files initProject() copies, so a template change
# there is tested here), then puts the fixture's files
# (tests/fixtures/<name>: plan, settings) on top, as a fresh git repository.
#   bash .shared-workflows/tests/self-test/make-analysis-project.sh analysis-project
set -euo pipefail

fixture=".shared-workflows/tests/fixtures/$1"
templates=".dsanalysis/inst/templates"
if [ ! -d "$fixture" ] || [ ! -d "$templates" ]; then
  echo "::error::Fixture '$1' or the dsAnalysis templates ($templates) are missing."
  exit 1
fi
mkdir -p R utils/setup utils/mock_data config results/tables results/figures
cp "$templates/datashield/main.R" R/main.R
cp "$templates/datashield/01_DS_Login.R" R/01_DS_Login.R
cp "$templates/dslite/01_DSLite_Setup.R" utils/setup/01_DSLite_Setup.R
cp "$templates/utils/config.yml" config.yml
cp "$templates/utils/dependencies.R" dependencies.R
cp -R "$fixture/." .
git init -q -b main .
printf '.shared-workflows/\n.dsanalysis/\n' >> .git/info/exclude
git -c user.name=self-test -c user.email=self-test@example.invalid add -A
git -c user.name=self-test -c user.email=self-test@example.invalid commit -qm "Fixture $1"
echo "Self-test on the analysis project $1 ($(git ls-files | wc -l) files)."
