require "sqlite3"

module CustomApp::Storable
  extend ActiveSupport::Concern

  MAX_DATABASE_SIZE = 50.megabytes

  def database_path
    Rails.root.join("storage", "agents", agent_id.to_s, "app_data", "#{id}.db")
  end

  def with_database
    FileUtils.mkdir_p(database_path.dirname)
    db = SQLite3::Database.new(database_path.to_s)
    db.busy_timeout = 5000
    db.results_as_hash = true
    db.execute("PRAGMA journal_mode=WAL")
    yield db
  ensure
    db&.close
  end

  def create_table(name, columns)
    validate_table_name!(name)
    col_defs = columns.map { |col| "#{sanitize_identifier(col["name"])} #{sanitize_type(col["type"] || "TEXT")}" }
    with_database do |db|
      db.execute("CREATE TABLE IF NOT EXISTS #{sanitize_identifier(name)} (id INTEGER PRIMARY KEY AUTOINCREMENT, #{col_defs.join(", ")})")
    end
  end

  def list_tables
    with_database do |db|
      db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").map { |row| row["name"] }
    end
  end

  def drop_table(name)
    validate_table_name!(name)
    with_database do |db|
      db.execute("DROP TABLE IF EXISTS #{sanitize_identifier(name)}")
    end
  end

  def query(table, where: nil, limit: 100, offset: 0)
    validate_table_name!(table)
    enforce_size_limit!

    with_database do |db|
      sql = "SELECT * FROM #{sanitize_identifier(table)}"
      params = []

      if where.is_a?(Hash) && where.any?
        conditions = where.map do |key, value|
          params << value
          "#{sanitize_identifier(key)} = ?"
        end
        sql += " WHERE #{conditions.join(" AND ")}"
      end

      sql += " LIMIT ? OFFSET ?"
      params += [ limit.to_i.clamp(1, 1000), offset.to_i ]

      db.execute(sql, params)
    end
  end

  def get_row(table, row_id)
    validate_table_name!(table)
    with_database do |db|
      db.execute("SELECT * FROM #{sanitize_identifier(table)} WHERE id = ?", [ row_id.to_i ]).first
    end
  end

  def insert_row(table, data)
    validate_table_name!(table)
    enforce_size_limit!

    with_database do |db|
      columns = data.keys.map { |k| sanitize_identifier(k) }
      placeholders = Array.new(columns.size, "?")
      sql = "INSERT INTO #{sanitize_identifier(table)} (#{columns.join(", ")}) VALUES (#{placeholders.join(", ")})"
      db.execute(sql, data.values)
      db.last_insert_row_id
    end
  end

  def update_row(table, row_id, data)
    validate_table_name!(table)
    with_database do |db|
      sets = data.keys.map { |k| "#{sanitize_identifier(k)} = ?" }
      sql = "UPDATE #{sanitize_identifier(table)} SET #{sets.join(", ")} WHERE id = ?"
      db.execute(sql, data.values + [ row_id.to_i ])
      db.changes
    end
  end

  def delete_row(table, row_id)
    validate_table_name!(table)
    with_database do |db|
      db.execute("DELETE FROM #{sanitize_identifier(table)} WHERE id = ?", [ row_id.to_i ])
      db.changes
    end
  end

  private
    def validate_table_name!(name)
      raise ArgumentError, "Invalid table name" unless name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]{0,63}\z/)
    end

    def sanitize_identifier(name)
      raise ArgumentError, "Invalid identifier: #{name}" unless name.to_s.match?(/\A[a-zA-Z_][a-zA-Z0-9_]{0,63}\z/)
      "\"#{name}\""
    end

    def sanitize_type(type)
      allowed = %w[ TEXT INTEGER REAL BLOB NUMERIC ]
      type = type.to_s.upcase
      allowed.include?(type) ? type : "TEXT"
    end

    def enforce_size_limit!
      return unless database_path.exist?
      if File.size(database_path) > MAX_DATABASE_SIZE
        raise "Database size limit exceeded (#{MAX_DATABASE_SIZE / 1.megabyte}MB max)"
      end
    end
end
