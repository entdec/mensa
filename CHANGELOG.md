# Changelog

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