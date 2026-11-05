# frozen_string_literal: true

class AddSimulatedToStocks < ActiveRecord::Migration[8.1]
  def change
    add_column :stocks, :simulated, :boolean, default: false, null: false
  end
end
