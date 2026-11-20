# frozen_string_literal: true

module Mensa
  # Represents a batch action that can be applied to multiple selected records.
  #
  # batch :archive do
  #   title "Archive"
  #   form "users/archive_form"
  #   process do |users, batch|
  #     users.update_all(archived_reason: batch.params[:reason])
  #   end
  # end
  class BatchAction
    include ConfigReaders

    defined_by Mensa::Config::BatchDsl

    attr_reader :name, :table

    def initialize(name, config:, table:)
      @name = name
      @table = table
      @config = config
    end

    config_reader :title
    config_reader :description
    config_reader :form
    config_reader :confirm
    config_reader :show, call: false
    config_reader :process, call: false

    def form?
      form.present?
    end

    # Whether +view_context+'s user sees, and may run, the action
    def show?(view_context = nil)
      evaluate(view_context, show, table) ? true : false
    end

    # Runs the action for +batch+. A block that only takes the records gets
    # them as an Array, as it always did; one that also takes the batch gets a
    # relation.
    def perform(batch, view_context = nil)
      args = (process.arity == 1) ? [batch.records.to_a] : [batch.records, batch]
      evaluate(view_context, process, *args)
    end

    private

    # Runs +block+ in the view context, so route helpers work in it, like they
    # do in links. Lambdas get only as many arguments as they take.
    def evaluate(view_context, block, *args)
      args = args.first(block.arity) if block.lambda? && block.arity >= 0
      view_context ? view_context.instance_exec(*args, &block) : block.call(*args)
    end
  end
end
