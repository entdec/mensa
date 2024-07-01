# Mensa

Fast and awesome tables, with pagination, sorting, filtering and custom views.

Wanted features:

- [x] very fast
- [x] row-links
- [x] sorting
- [x] tables without headers (and without most of the above)
- [ ] column sorting
- [ ] filtering (of multiple columns, single is done)
- [ ] view selection and exports per view
- [ ] group by
- [ ] sum/max/min
- [ ] tables backed by arrays (of ActiveModel)

Todo:

- [ ] Hide filter icon in case there are no filters
- [ ] Search only works on table columns

## Usage

Add tables in your app/tables folder, inheriting from ApplicationTable.
This in turn should inherit from Mensa::Base.

```ruby
class UserTable < ApplicationTable
  definition do
    model User # implicit from name

    order name: :desc

    column(:name) do
      attribute :name # Optional, we can deduct this from the column name
      sortable true
      sanitize true
      internal false
      method nil
      visible true
      filter do
        collection -> { }
        scope -> { where(name: ...) }
      end
    end

    column(:nr_of_roles) do
      attribute "roles_count" # We use a database column here
    end

    # You can add one or more actions to a row
    action :delete do
      link { |user| user_path(user) }
      icon "fa-regular fa-trash"
      link_attributes data: {"turbo-confirm": "Are you sure you want to delete the user?", "turbo-method": :delete}
      show ->(user) { true }
    end

    link { |user| edit_user_path(user) }
    supports_views true # This table supports custom views
    show_header true
    view_columns_sorting false # Disabled for now
    view_condensed false # Default false
    view_condensed_toggle true # Whether to show the toggle, default true
  end
end
```

Currently mensa depends on satis, but that is something we might remove in a future version.
You can show your tables on the page using the following:

```slim
  = sts.table :users
```

### Fast

Mensa selects only the data it needs, based on the columns. Sometimes it needs additional columns to do it's work, but you don't want them displayed.
This can be done by adding `internal true` to the column definition.

```ruby
column :born_on do
  internal true # Needed for age below
end
column :age do
  attribute "EXTRACT(YEAR FROM AGE(born_on))::int"
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem "mensa"
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install mensa
```

Always use `bundle` to install the gem. Next use the install generator to install migrations, add an initializer and do other setup:

```bash
$  bin/rails g mensa:install
```

## Contributing

```
Contribution directions go here.



## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
```
