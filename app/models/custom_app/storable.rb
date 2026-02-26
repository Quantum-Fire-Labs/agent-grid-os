require "sqlite3"

module CustomApp::Storable
  extend ActiveSupport::Concern

  MAX_DATABASE_SIZE = 50.megabytes

  def database_path
    storage_path.join("data.db")
  end

  def with_database
    if defined?(@_active_database) && @_active_database
      return yield @_active_database
    end

    FileUtils.mkdir_p(database_path.dirname)
    db = SQLite3::Database.new(database_path.to_s)
    db.busy_timeout = 5000
    db.results_as_hash = true
    db.execute("PRAGMA journal_mode=WAL")
    @_active_database = db
    yield db
  ensure
    if db
      @_active_database = nil
      db.close
    end
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

  def tables_schema
    list_tables.map do |table|
      { "name" => table, "columns" => table_columns(table) }
    end
  end

  def table_columns(table)
    validate_table_name!(table)

    with_database do |db|
      db.execute("PRAGMA table_info(#{sanitize_identifier(table)})").map do |row|
        {
          "name" => row["name"],
          "type" => row["type"],
          "notnull" => row["notnull"].to_i == 1,
          "default" => row["dflt_value"],
          "pk" => row["pk"].to_i == 1
        }
      end
    end
  end

  def drop_table(name)
    validate_table_name!(name)
    with_database do |db|
      db.execute("DROP TABLE IF EXISTS #{sanitize_identifier(name)}")
    end
  end

  def query(table, where: nil, limit: 100, offset: 0, order: nil, select: nil)
    validate_table_name!(table)
    enforce_size_limit!

    with_database do |db|
      select_sql = if select.is_a?(Array) && select.any?
        select.map { |col| sanitize_identifier(col) }.join(", ")
      else
        "*"
      end

      sql = "SELECT #{select_sql} FROM #{sanitize_identifier(table)}"
      params = []

      if where.is_a?(Hash) && where.any?
        conditions = where.map do |key, value|
          params << value
          "#{sanitize_identifier(key)} = ?"
        end
        sql += " WHERE #{conditions.join(" AND ")}"
      end

      if order.present?
        sql += " ORDER BY #{build_order_clause(order)}"
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

  def update_rows(table, where:, data:, max_rows:)
    validate_table_name!(table)
    raise ArgumentError, "max_rows is required" if max_rows.blank?
    raise ArgumentError, "data must not be empty" if data.blank?

    with_database do |db|
      sql = "UPDATE #{sanitize_identifier(table)} SET "
      sql << data.keys.map { |k| "#{sanitize_identifier(k)} = ?" }.join(", ")

      params = data.values
      sql, params = append_where_clause(sql, params, where)

      matched = db.get_first_value("SELECT COUNT(*) FROM #{sanitize_identifier(table)}#{build_where_sql(where)}", build_where_params(where)).to_i
      raise ArgumentError, "row limit exceeded (matched #{matched}, max #{max_rows})" if matched > max_rows.to_i

      db.execute(sql, params)
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

  def delete_rows(table, where:, max_rows:)
    validate_table_name!(table)
    raise ArgumentError, "max_rows is required" if max_rows.blank?

    with_database do |db|
      matched = db.get_first_value("SELECT COUNT(*) FROM #{sanitize_identifier(table)}#{build_where_sql(where)}", build_where_params(where)).to_i
      raise ArgumentError, "row limit exceeded (matched #{matched}, max #{max_rows})" if matched > max_rows.to_i

      sql = "DELETE FROM #{sanitize_identifier(table)}"
      params = []
      sql, params = append_where_clause(sql, params, where)
      db.execute(sql, params)
      db.changes
    end
  end

  def save_row(table, match:, data:)
    validate_table_name!(table)
    raise ArgumentError, "match must not be empty" if match.blank?
    raise ArgumentError, "data must not be empty" if data.blank?

    with_transaction do
      existing = query(table, where: match, limit: 1, offset: 0).first
      if existing
        update_row(table, existing["id"], data)
        { action: "updated", id: existing["id"] }
      else
        row_id = insert_row(table, data)
        { action: "created", id: row_id }
      end
    end
  end

  def with_transaction
    with_database do |db|
      db.transaction
      result = yield
      db.commit
      result
    rescue Exception
      db.rollback rescue nil
      raise
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

    def build_order_clause(order)
      clauses = Array(order).map do |entry|
        if entry.is_a?(Hash)
          column = sanitize_identifier(entry["column"] || entry[:column])
          direction = (entry["direction"] || entry[:direction]).to_s.upcase
          direction = %w[ASC DESC].include?(direction) ? direction : "ASC"
          "#{column} #{direction}"
        else
          "#{sanitize_identifier(entry)} ASC"
        end
      end

      clauses.join(", ")
    end

    def append_where_clause(sql, params, where)
      return [ sql, params ] unless where.is_a?(Hash) && where.any?

      conditions = where.map do |key, value|
        params << value
        "#{sanitize_identifier(key)} = ?"
      end

      [ "#{sql} WHERE #{conditions.join(" AND ")}", params ]
    end

    def build_where_sql(where)
      return "" unless where.is_a?(Hash) && where.any?

      conditions = where.map { |key, _| "#{sanitize_identifier(key)} = ?" }
      " WHERE #{conditions.join(" AND ")}"
    end

    def build_where_params(where)
      return [] unless where.is_a?(Hash) && where.any?

      where.values
    end

    def enforce_size_limit!
      return unless database_path.exist?
      if File.size(database_path) > MAX_DATABASE_SIZE
        raise "Database size limit exceeded (#{MAX_DATABASE_SIZE / 1.megabyte}MB max)"
      end
    end
end
