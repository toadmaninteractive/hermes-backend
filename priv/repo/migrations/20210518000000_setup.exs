defmodule Repo.Migrations.Setup do
  use Ecto.Migration

  @timestamps_opts inserted_at: :created_at

  def change do

    #---------------------------------------------------------------------------
    # properties
    #---------------------------------------------------------------------------

    create table("properties", primary_key: false) do
      add :name,            :string, null: false, primary_key: true
      add :value,           :string
      timestamps(@timestamps_opts)
    end

    create constraint "properties", "name_can_not_be_empty", check: "trim(name) <> ''"

    create unique_index "properties", [:name]

    #---------------------------------------------------------------------------
    # settings
    #---------------------------------------------------------------------------

    create table("settings", primary_key: false) do
      add :name,            :string, null: false, primary_key: true
      add :type,            :string, null: false
      add :value,           :string
      timestamps(@timestamps_opts)
    end

    create constraint "settings", "name_can_not_be_empty", check: "trim(name) <> ''"
    create constraint "settings", "type_can_not_be_empty", check: "trim(type) <> ''"

    create unique_index "settings", [:name]

    #---------------------------------------------------------------------------
    # countries
    #---------------------------------------------------------------------------

    create table("countries") do
      add :name,            :string, null: false
      add :alpha2,          :string, size: 2, null: false
      add :alpha3,          :string, size: 3, null: false
      timestamps(@timestamps_opts)
    end

    create constraint "countries", "name_can_not_be_empty", check: "trim(name) <> ''"
    create constraint "countries", "alpha2_can_not_be_empty", check: "trim(alpha2) <> ''"
    create constraint "countries", "alpha3_can_not_be_empty", check: "trim(alpha3) <> ''"

    create unique_index "countries", [:name]
    create unique_index "countries", [:alpha2]
    create unique_index "countries", [:alpha3]

    #---------------------------------------------------------------------------
    # personnel user accounts
    #---------------------------------------------------------------------------

    create table("users") do
      add :rev,             :integer, default: 1
      add :username,        :string, null: false
      add :name,            :string
      add :email,           :string
      add :phone,           :string
      add :supervisor_id,   references("users", on_delete: :nilify_all)
      # add :office_id,       references("offices", on_delete: :nilify_all)
      add :location,        :string
      add :department,      :string
      add :job_title,       :string
      add :is_blocked,      :boolean, default: false
      add :is_deleted,      :boolean, default: false
      timestamps(@timestamps_opts)
    end

    create constraint "users", "username_can_not_be_empty", check: "trim(username) <> ''"
    create constraint "users", "email_can_not_be_empty", check: "trim(email) <> ''"
    create constraint "users", "phone_can_not_be_empty", check: "trim(phone) <> ''"

    create unique_index "users", [:username]
    create unique_index "users", ["(lower(trim(username)))"], name: :users_username_ult_index
    create unique_index "users", ["(lower(trim(email)))"], name: :users_email_ult_index
    create unique_index "users", ["(lower(trim(phone)))"], name: :users_phone_ult_index
    create index "users", [:supervisor_id]
    # create index "users", [:office_id]
    create index "users", [:location]
    create index "users", [:department]
    create index "users", [:job_title]
    create index "users", [:is_blocked]
    create index "users", [:is_deleted]
    create index "users", [:created_at]
    create index "users", [:updated_at]

    #---------------------------------------------------------------------------
    # personnel groups
    #---------------------------------------------------------------------------

    create table("groups") do
      add :rev,             :integer, default: 1
      add :name,            :string, null: false
      add :description,     :string
      add :is_superadmin,   :boolean, default: false
      add :is_deleted,      :boolean, default: false
      timestamps(@timestamps_opts)
    end

    create constraint "groups", "name_can_not_be_empty", check: "trim(name) <> ''"

    create unique_index "groups", [:name]
    create unique_index "groups", ["(lower(trim(name)))"], name: :groups_name_ult_index
    create index "groups", [:is_superadmin]
    create index "groups", [:is_deleted]
    create index "groups", [:created_at]
    create index "groups", [:updated_at]

    #---------------------------------------------------------------------------
    # personnel user group membership
    #---------------------------------------------------------------------------

    create table(:user_group_membership, primary_key: false) do
      add :user_id,         references("users", on_delete: :delete_all), null: false, primary_key: true
      add :group_id,        references("groups", on_delete: :delete_all), null: false, primary_key: true
    end

    # create unique_index :user_group_membership, [:user_id, :group_id]
    create index "user_group_membership", [:user_id]
    create index "user_group_membership", [:group_id]

    #---------------------------------------------------------------------------
    # company offices
    #---------------------------------------------------------------------------

    create table("offices") do
      add :rev,             :integer, default: 1
      add :name,            :string, null: false
      add :country_id,      references("countries", on_delete: :delete_all)
      add :city,            :string
      add :address,         :string
      add :postal_code,     :string
      add :group_id,        references("groups", on_delete: :nilify_all)
      timestamps(@timestamps_opts)
    end

    create constraint "offices", "name_can_not_be_empty", check: "trim(name) <> ''"

    create unique_index "offices", [:name]
    create unique_index "offices", ["(lower(trim(name)))"], name: :offices_name_ult_index
    create index "offices", [:country_id]
    create index "offices", [:created_at]
    create index "offices", [:updated_at]

    # link personnel user accounts to offices
    alter table("users") do
      add :office_id,       references("offices", on_delete: :nilify_all)
    end
    create index "users", [:office_id]

    #---------------------------------------------------------------------------
    # user sessions
    #---------------------------------------------------------------------------

    create table("sessions", primary_key: false) do
      add :id,              :varchar, null: false, primary_key: true
      add :user_id,         references("users", on_delete: :delete_all), null: false
      add :valid_thru,      :naive_datetime, null: false
      timestamps(@timestamps_opts)
    end

    create index "sessions", [:user_id]
    create index "sessions", [:valid_thru]
    create index "sessions", [:created_at]

    #---------------------------------------------------------------------------
    # projects
    #---------------------------------------------------------------------------

    create table("projects") do
      add :rev,             :integer, default: 1
      add :title,           :string, null: false
      add :key,             :string, null: false
      add :supervisor_id,   references("users", on_delete: :nilify_all)
      add :leading_office_id, references("offices", on_delete: :nilify_all)
      timestamps(@timestamps_opts)
    end

    create constraint "projects", "title_can_not_be_empty", check: "trim(title) <> ''"
    create constraint "projects", "key_can_not_be_empty", check: "trim(key) <> ''"

    create unique_index "projects", ["(lower(trim(title)))"], name: :projects_title_ult_index
    create unique_index "projects", ["(lower(trim(key)))"], name: :projects_key_ult_index
    create index "projects", [:created_at]
    create index "projects", [:updated_at]

    #---------------------------------------------------------------------------
    # dayslots
    #---------------------------------------------------------------------------

    create table("dayslots") do
      add :user_id,         references("users", on_delete: :nilify_all)
      add :project_id,      references("projects", on_delete: :nilify_all)
      add :slot_date,       :naive_datetime, null: false
      add :slot_date_iso,   :string, null: false
      add :time_off,        :string
      timestamps(@timestamps_opts)
    end

    create index "dayslots", [:created_at]
    create index "dayslots", [:updated_at]

  #   #---------------------------------------------------------------------------
  #   # personnel role membership
  #   #---------------------------------------------------------------------------

  #   create table(:user_role, primary_key: false) do
  #     add :user_id,         references("users", on_delete: :delete_all), null: false, primary_key: true
  #     add :office_id,       references("offices", on_delete: :delete_all), null: false, primary_key: true
  #     add :role,            :integer, null: false
  #   end

  #   create index :user_role, [:user_id]
  #   create index :user_role, [:office_id]
  #   create index :user_role, [:role]

  #   #---------------------------------------------------------------------------
  #   # personnel group role membership
  #   #---------------------------------------------------------------------------

  #   create table(:group_role, primary_key: false) do
  #     add :group_id,        references(:personnel, on_delete: :delete_all), null: false, primary_key: true
  #     add :office_id,       references("offices", on_delete: :delete_all), null: false, primary_key: true
  #     add :role,            :integer, null: false
  #   end

  #   create index :group_role, [:group_id]
  #   create index :group_role, [:office_id]
  #   create index :group_role, [:role]

  end
end
