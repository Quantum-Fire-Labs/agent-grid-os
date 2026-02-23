class RenameCustomAppNameToSlugAndAddName < ActiveRecord::Migration[8.1]
  def up
    rename_column :custom_apps, :name, :slug
    add_column :custom_apps, :name, :string

    CustomApp.reset_column_information
    CustomApp.find_each { |app| app.update_column(:name, app.slug.titleize) }

    change_column_null :custom_apps, :name, false
  end

  def down
    remove_column :custom_apps, :name
    rename_column :custom_apps, :slug, :name
  end
end
