# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_22_000001) do
  create_table "application_drafts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.boolean "favorited", default: false, null: false
    t.text "feedback"
    t.integer "job_application_id", null: false
    t.string "kind", null: false
    t.string "label"
    t.integer "parent_draft_id"
    t.json "selection"
    t.datetime "updated_at", null: false
    t.index ["job_application_id"], name: "index_application_drafts_on_job_application_id"
    t.index ["parent_draft_id"], name: "index_application_drafts_on_parent_draft_id"
  end

  create_table "generated_resumes", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "focus"
    t.string "model"
    t.text "params"
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  create_table "job_application_quotes", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "job_application_id", null: false
    t.integer "source_id"
    t.string "source_type"
    t.datetime "updated_at", null: false
    t.index ["job_application_id"], name: "index_job_application_quotes_on_job_application_id"
    t.index ["source_type", "source_id"], name: "index_job_application_quotes_on_source"
  end

  create_table "job_applications", force: :cascade do |t|
    t.date "applied_at"
    t.string "company"
    t.datetime "created_at", null: false
    t.text "description"
    t.text "gap_tags"
    t.text "notes"
    t.string "status", default: "saved", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "posts", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "published_at"
    t.string "slug", null: false
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_posts_on_published_at"
    t.index ["slug"], name: "index_posts_on_slug", unique: true
  end

  create_table "posts_projects", id: false, force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "project_id", null: false
    t.index ["post_id", "project_id"], name: "index_posts_projects_on_post_id_and_project_id", unique: true
    t.index ["project_id", "post_id"], name: "index_posts_projects_on_project_id_and_post_id"
  end

  create_table "posts_roles", id: false, force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "role_id", null: false
    t.index ["post_id", "role_id"], name: "index_posts_roles_on_post_id_and_role_id", unique: true
    t.index ["role_id", "post_id"], name: "index_posts_roles_on_role_id_and_post_id"
  end

  create_table "projects", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.date "ended_at"
    t.integer "role_id"
    t.string "slug", null: false
    t.date "started_at"
    t.string "status", default: "active", null: false
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["role_id"], name: "index_projects_on_role_id"
    t.index ["slug"], name: "index_projects_on_slug", unique: true
    t.index ["started_at"], name: "index_projects_on_started_at"
  end

  create_table "roles", force: :cascade do |t|
    t.text "body"
    t.string "company", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "slug", null: false
    t.date "start_date"
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["company", "title"], name: "index_roles_on_company_and_title"
    t.index ["slug"], name: "index_roles_on_slug", unique: true
  end

  create_table "taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.integer "taggable_id", null: false
    t.string "taggable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id", "taggable_type", "taggable_id"], name: "index_taggings_on_tag_and_taggable", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable_type_and_taggable_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "taxonomy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["taxonomy_id", "name"], name: "index_tags_on_taxonomy_id_and_name", unique: true
    t.index ["taxonomy_id", "slug"], name: "index_tags_on_taxonomy_id_and_slug", unique: true
    t.index ["taxonomy_id"], name: "index_tags_on_taxonomy_id"
  end

  create_table "taxonomies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_taxonomies_on_name", unique: true
    t.index ["slug"], name: "index_taxonomies_on_slug", unique: true
  end

  add_foreign_key "application_drafts", "application_drafts", column: "parent_draft_id"
  add_foreign_key "application_drafts", "job_applications"
  add_foreign_key "job_application_quotes", "job_applications"
  add_foreign_key "projects", "roles"
  add_foreign_key "taggings", "tags"
  add_foreign_key "tags", "taxonomies"
end
