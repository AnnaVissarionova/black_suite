class AddCounterCacheToProjectsAndExperiments < ActiveRecord::Migration[7.0]
  def change
    # Добавляем counter cache колонки
    add_column :projects, :experiments_count, :integer, default: 0, null: false
    add_column :experiments, :json_results_count, :integer, default: 0, null: false

    # Добавляем индексы для ускорения запросов
    add_index :projects, :user_id unless index_exists?(:projects, :user_id)
    add_index :projects, :created_at unless index_exists?(:projects, :created_at)
    add_index :experiments, :project_id unless index_exists?(:experiments, :project_id)
    add_index :experiments, :created_at unless index_exists?(:experiments, :created_at)
    add_index :json_results, :experiment_id unless index_exists?(:json_results, :experiment_id)
    add_index :json_results, :created_at unless index_exists?(:json_results, :created_at)

    # Пересчитываем существующие счётчики
    reversible do |dir|
      dir.up do
        # Обновляем счётчики для существующих записей
        execute <<-SQL.squish
          UPDATE projects
          SET experiments_count = (
            SELECT COUNT(*)
            FROM experiments
            WHERE experiments.project_id = projects.id
          )
        SQL

        execute <<-SQL.squish
          UPDATE experiments
          SET json_results_count = (
            SELECT COUNT(*)
            FROM json_results
            WHERE json_results.experiment_id = experiments.id
          )
        SQL
      end
    end
  end
end
