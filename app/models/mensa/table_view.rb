module Mensa
  class TableView < ApplicationRecord
    belongs_to :user, optional: true
  end
end
