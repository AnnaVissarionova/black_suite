class CreateJsonResults < ActiveRecord::Migration[8.0]
  def change
    create_table :json_results do |t|
      t.references :experiment, null: false, foreign_key: true
      t.jsonb :metadata

      t.timestamps
    end
  end
end
