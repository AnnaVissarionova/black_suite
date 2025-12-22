class AddShareTokensToProjectsAndExperiments < ActiveRecord::Migration[7.0]
  def change
    # Добавляем поля для шаринга в projects
    add_column :projects, :share_token, :string
    add_column :projects, :share_mode, :string, default: 'private'
    add_index :projects, :share_token, unique: true

    # Добавляем поле для шаринга в experiments
    add_column :experiments, :share_token, :string
    add_index :experiments, :share_token, unique: true
  end
end
