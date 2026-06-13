# Mensa

Fast and awesome tables, with pagination, sorting, filtering, batch processing, column hiding, column ordering and custom views.
Due to search, it only works with postgresql at the moment.

![table](./docs/table.png)
![filters](./docs/filters.png)
![columns](./docs/columns.png)
![export](./docs/export.png)

Features:
- [x] Very fast
- [x] Row-links
- [x] Sorting
- [x] Filtering of multiple columns
- [X] Hide filter icon in case there are no filters
- [X] Column ordering
- [X] Editing of existing filters
- [X] View selection and exports per view
- [X] Multiple selection of rows and batch processing
- [x] Tables without headers (and without most of the above)
- [X] Search works on all table columns
- [X] Exports can be scheduled to run recurring (daily/weekly/monthly/quarterly/bi-yearly/yearly)
      You will have to bring your own mailer, see configuration for details.

Nice to haves:

- [ ] group by
- [ ] sum/max/min
- [ ] tables backed by arrays (of ActiveModel)

## Usage

Add tables in your app/tables folder, inheriting from ApplicationTable.
This in turn should inherit from Mensa::Base.

You can give columns an arbitrary name, it can match the database column, translations will be taken from `activerecord.attributes.<model>.<column>`:

```yaml
en: 
  activerecord:
    attributes:
      user:
        name: Full name
```

```ruby
class UserTable < ApplicationTable
  model User # implicit from name

  order name: :desc

  column(:name) do
    filter
  end

  column(:nr_of_roles) do
    attribute "roles_count" # We use a database column here
  end

  # You can add one or more actions to a row
  action :delete do
    title "Delete row"
    link { |user| user_path(user) }
    icon "fa-regular fa-trash"
    # You could also give it a block, which takes the record as an argument, to choose icons dynamically
    # icon { |product| product.inventory? ? "fal fa-shelves" : "fal fa-shelves-empty" }
    link_attributes data: {"turbo-confirm": "Are you sure you want to delete the user?", "turbo-method": :delete}
    show ->(user) { true }
  end

  link { |user| edit_user_path(user) }

  show_header true
  view_columns_ordering false # Disabled for now

  # Add system views
  # Mensa will always create a systemview (:default) with name 'All' showing all records. 
  # If you want to rename it, for example because you don't show all records in your default scope, add it and give it a name like below.
  view :default do
    name "Default"
    description "Some descriptive text"
  end
  view :concept do
    name "Concept"
    filter :state do
      operator :is
      value "concept"
    end
  end
  
  batch :confirm do
    description "Confirm users"
    process do |records|
      ConfirmUsersJob.perform_later(records.to_a)
    end
  end

  scope do
    User.all
  end
end
```

You can show your tables on the page using the following:

```erb
<%= table :users %>
```

#### Custom views

Custom views are views not defined by the developer (SystemViews) but by the end-user by adding/removing filters.
When you enable these, they are stored in the database and can be used across sessions, by the user who created them.

### Fast

Mensa selects only the data it needs, based on the columns. Sometimes it needs additional columns to do it's work, but you don't want them displayed. This can be done by adding `internal true` to the column definition, or shorter: use `internal` instead. If your table scope joins an association, Mensa also auto-adds the foreign key column as internal when it is needed.

```ruby
internal :born_on
column :age do
  attribute "EXTRACT(YEAR FROM AGE(born_on))::int" # here born_on is used internally, so we ned to select is
end
```

## Development

### Coding

- Checkout this repo
- Setup your direnv, add the following to your `mise.toml`:

  ```
  [tools]
  node = "24"
  ruby = "3.4.7"
  
  [env]
  RUBY_VERSION="3.4.7"
  ```

- Run `direnv allow`
- Run `overmind s`

### Docs

Using the following in your view will render Mensa::Table::Component
```erb
<%= table :users %>
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
$ rails g mensa:install
$ rails mensa:install:migrations
```

Next you can run the generator to generate a table:

```bash
$ rails g mensa:table:generate <model_name>
```

### Exports

Exporting is built into the table's control bar. Clicking the export button opens
a dialog that lists the user's previous downloads and lets them request a new
export (scope and CSV format). 

#### Repeating exports

The user can choose to export a table on a regular basis (daily, weekly, monthly, quarterly, bi-yearly, yearly).

When the user selects a repeating export, the table will be exported automatically on the specified schedule.

For this to work you need to have a cron job which runs daily.
When using `sidekiq-cron` or `goodjob` the `RecurringExportsJob` needs to be scheduled to run daily.

If you're just using cron, you can add the following to your crontab:
```
0 0 * * * rails runner "Mensa::RecurringExportsJob.perform_later"
```

## Contributing

```
Contribution directions go here.



## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
```
