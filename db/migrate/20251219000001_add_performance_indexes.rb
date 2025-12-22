class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Составной индекс для сортировки экспериментов по проекту
    add_index :experiments, [:project_id, :created_at], 
              name: 'index_experiments_on_project_id_and_created_at'
    
    # Составной индекс для сортировки json_results по эксперименту
    add_index :json_results, [:experiment_id, :created_at], 
              name: 'index_json_results_on_experiment_id_and_created_at'
    
    # Индекс для быстрого поиска проектов пользователя с сортировкой
    add_index :projects, [:user_id, :created_at], 
              name: 'index_projects_on_user_id_and_created_at'
  end
end
