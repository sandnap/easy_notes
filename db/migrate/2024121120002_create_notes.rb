class CreateNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.string :title, null: false
      t.text :content
      t.references :category, null: false, foreign_key: true

      t.timestamps
    end

    add_index :notes, [ :category_id, :title ]
  end
end
