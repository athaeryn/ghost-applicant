class CreateTaxonomies < ActiveRecord::Migration[8.1]
  def change
    create_table :taxonomies do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description

      t.timestamps
    end

    add_index :taxonomies, :name, unique: true
    add_index :taxonomies, :slug, unique: true
  end
end
