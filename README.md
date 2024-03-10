# Mensa
Awesome tables

Wanted features:
* [X] very fast
* [X] row-links
* [X] sorting
* [X] tables without headers (and without most of the above)
* [ ] filtering (of multiple columns, single is done)
* [ ] view selection and exports per view
* [ ] group by
* [ ] sum/max/min
* [ ] tables backed by arrays (of ActiveModel)

## Usage

Add tables in your app/tables folder, inheriting from ApplicationTable.
This in turn should inherit from Mensa::Base.

```ruby
class UserTable < ApplicationTable
  model User # implicit from name

  order { name: :desc}
  
  column(:name) do
    attribute :name

    filter do
      collection -> { }
      scope -> { where(name: ...) }
    end
  end
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
