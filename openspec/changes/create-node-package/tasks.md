## 1. Environment and Package Foundation

- [ ] 1.1 Update `envs/env-r-4.3.yaml` with all R dependencies: randomForest, dplyr, ggplot2, reshape2, yaml, filelock
- [ ] 1.2 Verify conda environment can be created from `envs/env-r-4.3.yaml`
- [ ] 1.3 Add LICENSE (Apache 2.0) and README.md

## 2. SKILL.md Contract

- [ ] 2.1 Create `SKILL.md` with v2 YAML frontmatter (name, description, type, inputs, outputs, entry, parameters, exceptions, hardware)
- [ ] 2.2 Write narrative body sections: Node Function, Expected Input, Invocation, Expected Output, Exceptions, Reporting Requirements, Hardware Requirements

## 3. Core Script (scripts/main.R)

- [ ] 3.1 Create `scripts/main.R` with subcommand dispatch mechanism
- [ ] 3.2 Implement `train` subcommand: parse --in-mat, --in-map, --in-gene, --outdir, --seed, --top, --ntree
- [ ] 3.3 Implement randomForest::randomForest() call with ntree, importance, proximity
- [ ] 3.4 Implement 5-repeat 10-fold rfcv cross-validation
- [ ] 3.5 Implement gene selection by MeanDecreaseGini importance (top N or CV-optimal)
- [ ] 3.6 Generate all 7 output plots and files under --outdir
- [ ] 3.7 Emit NDJSON info + result lines to stdout, errors to stderr
- [ ] 3.8 Handle edge cases: empty gene list, missing input, file permission errors

## 4. Validation Scripts

- [ ] 4.1 Create `scripts/input_validation.R` checking file existence and CSV validity
- [ ] 4.2 Create `scripts/output_validation.R` checking all 7 output files exist and have expected structure

## 5. Test Suite

- [ ] 5.1 Create `tests/testthat/test-train.R` with happy path test using synthetic data
- [ ] 5.2 Add tests: missing input file, empty gene list, seed determinism
- [ ] 5.3 Add tests: unknown subcommand, invalid parameters
- [ ] 5.4 All tests pass with `Rscript -e 'testthat::test_dir("tests/testthat/")'`

## 6. Verification

- [ ] 6.1 Verify `scripts/main.R train` runs end-to-end with synthetic data
- [ ] 6.2 Verify all 7 output files are created and valid
- [ ] 6.3 Verify NDJSON stdout format and exit codes
- [ ] 6.4 Verify SKILL.md frontmatter parses as valid YAML
