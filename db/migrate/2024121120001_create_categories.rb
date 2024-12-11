class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.references :user, null: false, foreign_key: true
      t.integer :notes_count, default: 0, null: false  # Counter cache for notes

      t.timestamps
    end

    add_index :categories, [:user_id, :name], unique: true
  end
end
