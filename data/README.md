# Data provenance and snapshots

Publisher: Ministry of Domestic Trade and Cost of Living (KPDN) and Department of Statistics Malaysia (DOSM), via data.gov.my. Transaction catalogue: https://data.gov.my/data-catalogue/pricecatcher . Item catalogue: https://data.gov.my/data-catalogue/lookup_item . Premise catalogue: https://data.gov.my/data-catalogue/lookup_premise . All three catalogues specify CC BY 4.0: https://creativecommons.org/licenses/by/4.0/ . No endorsement is implied.

July 2026 transactions were supplied by the project owner; their original retrieval time is unknown. They were copied unchanged. Current official item and premise lookups were retrieved on 2 November 2026 (Malaysia time). Catalogue snapshot dates were 9 September 2026 for items and 27 October 2026 for premises. They are not historical July snapshots and can change joins, classifications and results.

The redistributed premise CSV excludes the `premise` and `address` fields to minimise unnecessary data. It retains premise_code, premise_type, state and district. The transformed file is identified by its own hash. The model does not need public business names or street addresses. All raw transaction values and item lookup fields remain unchanged. `input-manifest.json` gives filenames, original source URLs, hashes, sizes and transformation notes.

Transactions: date, premise_code, item_code, price (RM per item unit). Item lookup: item_code, item, unit, item_group, item_category. Retained premise lookup: premise_code, premise_type, state, district.

The full July file contains 1,815,849 rows, 2,122 premise codes and 341 item codes. Of these rows, 25,423 item codes have no match in the current lookup (row count, not distinct-code count). Zero premise rows are unmatched and zero prices are nonpositive or nonfinite. Retail and metadata filtering retains 1,624,094 rows before the supported basket is selected. This is price surveillance data, not a representative national CPI basket.

Malay format labels map to Hypermarket, Supermarket, Mini market, Sundry shop and Wet market. Product groups map to Packaged goods, Dry produce and Fresh produce. Sabah, Sarawak and W.P. Labuan comprise East Malaysia. Group names do not establish sourcing or freight exposure.
