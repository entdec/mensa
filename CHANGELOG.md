# Changelog

## 0.9.2

- The table tour no longer needs the `driver.js` npm package. Mensa now ships
  driver.js (1.10.1, MIT) itself in `app/components/mensa/table/driver.js` and
  imports it as `mensa/components/table/driver`, so host apps that bundle
  Mensa's JS with esbuild (jsbundling-rails) build again without adding
  anything. In 0.9.0 and 0.9.1 those builds failed with
  `Could not resolve "driver.js"`.
- driver.js is updated from 1.3.6 to 1.10.1; its CSS
  (`app/assets/stylesheets/mensa/driver.css`) is updated to the same version.
- The table tour has a dark mode. It follows the host app's Tailwind dark mode
  setting, like the rest of Mensa.
- The engine's importmap no longer pins `driver.js`. Host apps that import
  `driver.js` themselves need their own pin or npm package.

## 0.8.0

- **Behaviour change:** a column shows what was selected in SQL under its name
  (a database column, its `attribute` or an alias in the `scope`), and only
  calls a model method when it asks for one with `method`. Before, a model
  method with the same name as the column took its place, so
  `column(:contact) { attribute "concat_ws(...)" }` on a model with a
  `#contact` method showed the method's result. Columns that relied on a
  model method of their name need `method true`.
- `method true` calls the model method named after the column.
- The verifier warns about columns that are always empty: nothing is selected
  under their name and they have no `method` or `render`. When the model has a
  method of that name, it suggests `method true`.

## 0.7.4

- **Behaviour change:** the `matches` and `does_not_match` filters now do a
  case-insensitive "contains" (`ILIKE '%value%'`), the same way search does.
  Before, they passed the value to `LIKE` as it was, so `matches "LLC"` only
  found rows that were exactly `LLC`. The value is taken literally, so saved
  views that relied on typing `%` or `_` wildcards now match a literal `%` or
  `_`. `does_not_match` now also returns rows where the column is NULL.
  Attributes without a `type` are cast to text for the comparison.
- Search leaves out internal columns. They aren't shown, so a row found
  through one looked like it didn't match.

## 0.7.2

- The verifier's report only lists failures and warnings. `-v`/`--verbose` (or
  `VERBOSE=1`) on the rake tasks, or `result.to_s(verbose: true)`, lists every
  check, and the classes in `app/tables` that were skipped as they aren't Mensa
  tables.

## 0.7.0

- Filters only offer the operators that work for the column's type in SQL,
  picking one no longer raises. `matches`/`does_not_match` (`LIKE`) are only
  offered for string, text, citext and untyped attribute columns, so boolean,
  float, decimal, uuid, time and other columns no longer get them.
  `gt`/`gteq`/`lt`/`lteq` are only offered for number, date and time columns,
  so boolean, uuid and text columns no longer get them. json/jsonb columns only
  get `is_empty`/`isnt_empty` (and jsonb `is_duplicate`). Host apps no longer
  need to patch `Mensa::Filter#operators` or list `operators` per column to
  avoid these. An explicit `operators` list is used as given.
- Time columns use a time input, and a filter value that isn't a time matches
  nothing instead of raising.
- The verifier warns when an `attribute` has no `type` but its SQL isn't text,
  e.g. a boolean `EXISTS (...)`, and says which `type` to add.
- Columns a `column_order` doesn't list are kept and shown after the listed
  ones, instead of being dropped. Browser state or views saved before a column
  was added no longer hide that column (also from the column customizer),
  ignore filters and sorting on it, or leave its attribute unselected.
- The verifier checks column order and visibility: a reversed order, an order
  that lists only one column (like state saved before columns were added),
  hiding each column and hiding all of them, each rendered and exported.
- The verifier creates a custom view like a user saving the table's state
  would, without saving it, and validates, replays and exports it.
- The verifier confirms when it found no N+1 queries.

## 0.6.19

- `Mensa::Verifier` checks a table against the database: scope, column SQL,
  sorting, rendering, filters, search, CSV export, grouping/aggregates and
  views. Run it with `bin/rails "mensa:verify[table]"` / `mensa:verify_all`,
  or from tests after `require "mensa/testing"` with
  `assert_mensa_table_valid` or `be_a_valid_mensa_table`. Set defaults for
  its context with `config.verifier_context`.
- The verifier samples records from the first and last page and records with
  empty values, tries filters with invalid input, checks search, filters, sorting
  and grouping together, and warns about N+1 queries (with a fix) and slow
  queries. `strict: true` / `STRICT=1` makes warnings fail.
  `config.verifier_context` can return an array to verify tables in several
  contexts, `config.verifier_slow_query` sets when a query is slow.
- Columns without SQL (only a `render` block or a `method`, no `attribute` or
  database column) are no longer sortable or filterable by default, sorting or
  filtering on them produced invalid SQL. Use `sortable true` for a column whose
  name is an alias the scope selects, or a filter `scope` to filter it.
- Filters with a value their column's type can't hold (e.g. "abc" for a number,
  or an invalid date or uuid) match nothing instead of raising a database error.
- `Mensa::ExportJob.write_csv(io, table, rows)` writes a table's CSV export and
  `Mensa::ExportJob#generate_file(export)` generates an export's file without
  saving it.
- Exports of tables with a `csv` render block no longer fail: the export job
  renders with a view context of `config.base_controller`
  (`Mensa.offline_view_context`).
- Row actions without an `icon` show their title instead of raising.
- An unknown helper in a render block raises `NoMethodError` instead of
  `SystemStackError`. Only the app's `*_path`/`*_url` helpers are forwarded to
  `main_app`.
- Search leaves out columns with a `having` filter (aggregates), which broke the
  query.
- `is_duplicate` works for columns with a `having` filter.

## 0.6.16

- Custom filter `scope` blocks can take the operator as a second argument,
  e.g. `scope ->(value, operator) { ... }`, so they can handle `isnt`,
  `is_empty` and the other operators. Existing `->(value) { ... }` scopes keep
  working unchanged.

## 0.6.15

- Custom filter `scope` blocks now work. Applied filters are built from the
  column's `filter do ... end` definition (`scope`, `operators`, `multiple`,
  `collection`, `having`, ...) with the requested `value` and `operator`
  layered on top, and `Mensa::Filter#scope` returns the proc instead of
  calling it without arguments. Host apps can remove workarounds that patch
  `Mensa::Base#active_filters` or `Mensa::Filter#scope`.
- Only `value` and `operator` are taken from the request for applied filters;
  other filter options come from the column definition.
- Exports are refused (403) for tables with `exportable false`, instead of
  being created and failing in `Mensa::ExportJob`.

## 0.6.12

- Tables built with `params` (`table :name, params: {...}`) now work in filters,
  views, batch actions and exports. The params are sent to these endpoints as
  `params[...]` query parameters and stored on `Mensa::Export#config`, so
  `Mensa::ExportJob` (and recurring exports) rebuild the table with them.
  Host apps can remove their FiltersController, ExportsController and
  Table::Component patches for this.
- The export list, badge and Turbo stream are scoped per table params, so
  exports of e.g. two different queries on the same table are no longer mixed.
- Browser state (filters, search, order, column order, hidden columns) is
  stored per table params. Unknown column names in `column_order`,
  `hidden_columns`, `order` and `filters` are ignored instead of raising.
- The export completed callback is now `export_completed`, as documented in the
  generated initializer. The old `export_complete` name still works. Unknown
  callback names are logged as a warning.
- `selected_scope` only selects `id` when the relation has an `id` column.

## 0.2.4

- Renames the data column on table_views to config
- Adds descriptions to table view