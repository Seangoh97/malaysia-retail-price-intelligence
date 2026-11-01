# Model card

## Intended use

Offline review of whether a retail quote is high or low relative to a supported July 2026 item-format-region benchmark. Suitable for exploratory procurement and retail analysis with analyst review. Model users must verify units, item definitions, reference period and local conditions.

Not suitable for setting prices automatically, determining regulatory violations, estimating inflation, forecasting future prices or assigning causes to regional differences.

## Specification

OLS: `log_price ~ item_factor + format * region + east_dry + east_fresh`.

Reference format: Hypermarket. Reference region: Peninsular Malaysia. `east_dry` and `east_fresh` are product-group regional adjustments, avoiding redundant item-group main effects. A coefficient is conditional on the remaining terms. Regional differences depend on format as well as product group.

Benchmarks are `exp(X beta)`, conditional geometric means. They are not expected arithmetic prices or guaranteed medians. Quote differences use `100 * (quote / benchmark - 1)`. A high difference is a review signal, not evidence of error or misconduct. No anomaly classifier or arbitrary error label is used.

Covariance uses `sandwich::vcovCL`, HC1, clustered by stable premise code with cluster adjustment. Mean confidence limits are exponentiated t intervals with G−1 degrees of freedom. Cross-premise common shocks, district dependence, omitted quality differences and model misspecification remain unresolved. Narrow intervals do not mean accurate individual predictions.

## Data handling

The supplied July file has 1,815,849 records. Parsing errors, duplicate lookup keys, duplicate date/premise/item records and unknown states stop the run. Invalid prices, unmatched lookups, non-retail formats and incomplete descriptive fields are excluded with aggregate counts. Prices must be finite and positive. Original price extremes remain in the final model; an absolute standardized residual >4 sensitivity analysis is exported separately.

Eligibility is checked on development data only. Every eligible item must have ten format × region cells with at least 30 quotations and three premises each. Selection ranks one item per category by quote count, then takes up to four categories in each group, with stable ties. The resulting model has nine items. Only one packaged-good category qualifies, so its regional coefficient must not be generalised to packaged goods broadly.

The development model uses days 1–24 and excludes premise codes divisible by five. Two later-date sets test known and held-out premises. This evaluates a restricted within-month use case, not future-month transportability. The final all-July refit uses the same selected basket, including validation observations; it is a historical snapshot. Holdout metrics describe the development procedure, not a separate untouched evaluation of that final refit.

## Operational controls

Scoring rejects unknown items, formats, regions and non-positive/nonfinite prices. Each output states the reference month and includes item units. No business names or addresses are needed for scoring. Input hashes and package versions support repeatable runs; current upstream lookups may differ, so downloaded files must match the frozen manifest.

Refreshing to another month requires an official monthly file, explicitly reviewed lookup snapshots, new hashes, rerun validation and inspection of coverage and drift. Do not overwrite the frozen July manifest to hide a changed snapshot. The code supports a month argument, but no second month has been validated. Monitoring, scheduled refresh, multi-month backtesting, broader basket coverage and deployment security are future work.

## Method reference

Cluster covariance implementation and assumptions: https://sandwich.r-forge.r-project.org/reference/vcovCL.html . Official scope and caveats: https://data.gov.my/data-catalogue/pricecatcher .
