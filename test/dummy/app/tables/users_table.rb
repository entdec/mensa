# frozen_string_literal: true

class UsersTable < Mensa::Base

  definition do
    model User
    column(:first_name)
    column(:last_name)
    column(:updated_at)

    order name: 'asc'

    # link { |team| edit_team_path(team) }
  end

  # filter(:state, collection: -> { model.state_machine.states.map(&:name).sort })

  private

  def scope
    @scope = Users.all
    @scope
  end
end
