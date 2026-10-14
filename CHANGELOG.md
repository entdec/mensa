# Changelog

## Unreleased

- `Mensa::Verifier` checks a table against the database: scope, column SQL,
  sorting, rendering, filters, search, CSV export, grouping/aggregates and
  views. Run it with `bin/rails "mensa:verify[table]"` / `mensa:verify_all`,
  or from tests after `require "mensa/testing"` with
  `assert_mensa_table_valid` or `be_a_valid_mensa_table`. Set defaults for
  its context with `config.verifier_context`.
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