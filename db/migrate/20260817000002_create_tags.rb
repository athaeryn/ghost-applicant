class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.references :taxonomy, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description

      t.timestamps
    end

    add_index :tags, %i[taxonomy_id name], unique: true
    add_index :tags, %i[taxonomy_id slug], unique: true
  end
end
