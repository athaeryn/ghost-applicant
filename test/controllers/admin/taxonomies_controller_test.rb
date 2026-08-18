require "test_helper"

class Admin::TaxonomiesControllerTest < ActionDispatch::IntegrationTest
  test "creates a taxonomy and a tag within it" do
    assert_difference "Taxonomy.count", 1 do
      post admin_taxonomies_path, params: { taxonomy: { name: "industry", description: "Sectors" } }
    end
    assert_redirected_to admin_taxonomies_path
    taxonomy = Taxonomy.find_by(name: "industry")

    get admin_taxonomy_path(taxonomy)
    assert_response :success

    assert_difference "Tag.count", 1 do
      post admin_tags_path, params: { tag: { taxonomy_id: taxonomy.id, name: "fintech" } }
    end
    assert_redirected_to admin_taxonomy_path(taxonomy)
    assert taxonomy.tags.find_by(name: "fintech")
  end

  test "deleting a taxonomy removes its tags" do
    taxonomy = Taxonomy.create!(name: "skill")
    taxonomy.tags.create!(name: "ruby")
    assert_difference "Taxonomy.count", -1 do
      delete admin_taxonomy_path(taxonomy)
    end
    assert_empty Tag.where(taxonomy_id: taxonomy.id)
  end
end
