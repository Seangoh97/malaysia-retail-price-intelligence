# Validation and release checks

The operational pipeline was run end to end on the supplied July transactions and newly retrieved official lookup snapshots. Its final sample, basket, coefficients, covariance, benchmarks and metrics were generated anew. The earlier notebook and report were removed from the release to prevent conflicting figures or coursework claims from being mistaken for current outputs.

## Executed checks

- Raw schema and CSV parse checks; unique nonmissing lookup keys; valid month and transaction keys.
- Duplicate date/premise/item detection, finite positive prices and recognised state labels.
- Explicit ten-cell item coverage with minimum observations and distinct premises.
- Training-only item selection, disjoint development/held-out premises and strictly later evaluation dates.
- Finite predictions and comparison against the training item-only baseline.
- Rank checks, clustered covariance checks, supported output-cell checks and residual sensitivity output.
- Quote comparison arithmetic, confidence bounds and rejection of unsupported items/formats and invalid prices.
- Input checksum verification, exact model rerun comparison and a command-line scoring smoke check.

`results/run-manifest.json` contains actual counts and hashes. `results/validation.csv` contains both evaluation sets. `results/session-info.txt` records execution versions. Run `Rscript tests/run-tests.R` after fitting.

## Remaining limits

There is no proof that this software is error-free. Tests address observed data contracts and key numerical behavior, not every possible input or deployment scenario. Only one month has been tested. Evaluation is not randomised, lookup versions postdate observations and unobserved product quality can affect quote comparability. The full-data refit is not independently held out. No claim of production readiness, causal identification or financial benefit is made.
