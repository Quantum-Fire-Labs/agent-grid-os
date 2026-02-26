require "json"
require "net/http"
require "uri"
require "socket"
require "date"

class Missionbase
  BASE_URL = "https://dash.missionbase.app".freeze
  USER_AGENT = "AgentGridOS Missionbase Plugin/2.0".freeze
  JSON_HEADERS = {
    "Content-Type" => "application/json",
    "Accept" => "application/json"
  }.freeze
  TEAM_REQUIRED_TOOLS = %w[
    missionbase_list_team_boxes
    missionbase_list_team_members
    missionbase_list_current_user_tasks_by_team
    missionbase_list_active_tasks_by_team
  ].freeze
  CONVERSATION_STATUSES = %w[unread read snoozed archived].freeze

  class ToolArgumentError < StandardError; end
  class ApiError < StandardError; end

  def initialize(agent:)
    @agent = agent
  end

  def call(name, arguments)
    args = normalize_arguments(arguments)
    ensure_configured!
    ensure_team_id!(name, args) if TEAM_REQUIRED_TOOLS.include?(name)

    result = dispatch(name, args)
    format_tool_result(name, result, args)
  rescue ToolArgumentError => e
    "Missionbase tool error: #{e.message}"
  rescue ApiError => e
    "Missionbase API error: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    "Missionbase network error: #{e.message}"
  rescue JSON::ParserError => e
    "Missionbase response error: invalid JSON (#{e.message})"
  end

  private
    def dispatch(name, arguments)
      case name
      when "missionbase_list_teams"
        request_json(:get, "/api/v1/teams", query: slice(arguments, "status"))
      when "missionbase_get_current_user"
        request_json(:get, "/api/v1/users/me")
      when "missionbase_list_team_members"
        request_json(:get, "/api/v1/teams/#{require_arg!(arguments, "team_id")}/members", query: slice(arguments, "status"))
      when "missionbase_list_team_boxes"
        request_json(:get, "/api/v1/teams/#{require_arg!(arguments, "team_id")}/boxes", query: list_team_boxes_query(arguments))
      when "missionbase_create_box"
        create_box(arguments)
      when "missionbase_list_tasks_visible_to_current_user"
        request_json(:get, "/api/v1/tasks/visible", query: slice(arguments, "status", "box_id", "team_id", "date"))
      when "missionbase_list_tasks_assigned_to_current_user"
        request_json(:get, "/api/v1/tasks/assigned", query: slice(arguments, "status", "box_id", "team_id", "date", "include_overdue"))
      when "missionbase_list_current_user_tasks_by_team"
        request_json(:get, "/api/v1/tasks/assigned", query: slice(arguments, "team_id", "status", "box_id", "date", "include_overdue"))
      when "missionbase_list_tasks_by_box"
        list_tasks_by_box(arguments)
      when "missionbase_list_active_tasks_by_team"
        request_json(:get, "/api/v1/tasks/active_by_team", query: slice(arguments, "team_id", "box_id", "date"))
      when "missionbase_create_task"
        create_task(arguments)
      when "missionbase_update_task"
        update_task(arguments)
      when "missionbase_get_task"
        get_task(arguments)
      when "missionbase_assign_user_to_task"
        assign_user_to_task(arguments)
      when "missionbase_unassign_user_from_task"
        unassign_user_from_task(arguments)
      when "missionbase_list_conversations"
        list_conversations(arguments)
      when "missionbase_get_conversation"
        get_conversation(arguments)
      when "missionbase_update_conversation_status"
        update_conversation_status(arguments)
      when "missionbase_add_comment_to_task"
        add_comment_to_task(arguments)
      when "missionbase_add_comment_to_conversation"
        add_comment_to_conversation(arguments)
      when "missionbase_get_daily_note"
        get_daily_note(arguments)
      when "missionbase_update_daily_note"
        update_daily_note(arguments)
      when "missionbase_search_notes"
        request_json(:get, "/api/v1/notes/search", query: slice(arguments, "query", "type"))
      else
        raise ToolArgumentError, "unknown tool: #{name}"
      end
    end

    def list_team_boxes_query(arguments)
      query = slice(arguments, "status")
      include_closed = arguments["include_closed"]
      query["include_closed"] = include_closed if include_closed == true || include_closed == false
      query
    end

    def create_box(arguments)
      ownable_type = arguments["ownable_type"].presence || "User"
      body = {
        "name" => require_arg!(arguments, "name"),
        "status" => arguments["status"].presence || "open",
        "visibility" => arguments["visibility"].presence || "assigned",
        "ownable_type" => ownable_type
      }
      body["description"] = arguments["description"] if arguments["description"].present?

      if ownable_type == "Team"
        body["ownable_id"] = require_arg!(arguments, "ownable_id")
      end

      request_json(:post, "/api/v1/boxes", body: body)
    end

    def list_tasks_by_box(arguments)
      box_id = require_arg!(arguments, "box_id")
      query = slice(arguments, "status", "date")
      request_json(:get, "/api/v1/boxes/#{box_id}/tasks", query: query)
    end

    def create_task(arguments)
      assign_to_user_id = optional_positive_integer(arguments["assign_to_user_id"], key: "assign_to_user_id")
      box_id = optional_positive_integer(arguments["box_id"], key: "box_id")
      assign_to_current_user = truthy?(arguments["assign_to_current_user"])
      assign_to_user_id = nil if assign_to_current_user

      body = {
        "title" => require_arg!(arguments, "title")
      }
      body["description"] = arguments["description"] if arguments["description"].present?
      body["do_on"] = arguments["do_on"] if arguments["do_on"].present?
      body["deadline"] = arguments["deadline"] if arguments["deadline"].present?
      body["box_id"] = box_id if box_id.present?
      body["assign_to_current_user"] = true if assign_to_current_user
      body["assign_to_user_id"] = assign_to_user_id if assign_to_user_id.present?

      request_json(:post, "/api/v1/tasks", body: body)
    end

    def update_task(arguments)
      id = require_arg!(arguments, "id")
      body = slice(arguments, "title", "description", "status", "do_on")
      raise ToolArgumentError, "At least one field to update is required" if compact_hash(body).empty?

      request_json(:patch, "/api/v1/tasks/#{id}", body: body)
    end

    def get_task(arguments)
      id = require_arg!(arguments, "id")
      request_json(:get, "/api/v1/tasks/#{id}")
    end

    def assign_user_to_task(arguments)
      task_id = require_arg!(arguments, "task_id")
      user_id = require_arg!(arguments, "user_id")
      body = {
        "user_id" => user_id,
        "acting_as_user_id" => current_missionbase_user_id
      }
      request_json(:post, "/api/v1/tasks/#{task_id}/assignments", body: body)
    end

    def unassign_user_from_task(arguments)
      task_id = require_arg!(arguments, "task_id")
      user_id = require_arg!(arguments, "user_id")
      body = { "acting_as_user_id" => current_missionbase_user_id }
      request_json(:delete, "/api/v1/tasks/#{task_id}/assignments/#{user_id}", body: body)
    end

    def list_conversations(arguments)
      query = slice(arguments, "conversation_status", "box_id")
      query["conversation_status"] ||= %w[unread read]
      request_json(:get, "/api/v1/conversations", query: query)
    end

    def get_conversation(arguments)
      feed_id = pick_identifier(arguments, "feed_id", "id")
      query = slice(arguments, "limit")
      request_json(:get, "/api/v1/conversations/#{feed_id}", query: query)
    end

    def update_conversation_status(arguments)
      feed_id = pick_identifier(arguments, "feed_id", "id")
      status = require_arg!(arguments, "status")
      unless CONVERSATION_STATUSES.include?(status.to_s)
        raise ToolArgumentError, "status must be one of: #{CONVERSATION_STATUSES.join(', ')}"
      end

      request_json(:patch, "/api/v1/conversations/#{feed_id}", body: { "status" => status })
    end

    def add_comment_to_conversation(arguments)
      comment = require_arg!(arguments, "comment")
      feed_id = arguments["feed_id"].presence || arguments["conversation_id"].presence
      if feed_id.blank?
        if arguments["task_id"].present? || arguments["post_id"].present?
          raise ToolArgumentError, "Use missionbase_add_comment_to_task for task comments. This conversation tool supports feed_id in the REST-backed plugin transport."
        end
        raise ToolArgumentError, "feed_id is required"
      end

      request_json(:post, "/api/v1/conversations/#{feed_id}/comments", body: { "comment" => comment })
    end

    def add_comment_to_task(arguments)
      task_id = require_arg!(arguments, "task_id")
      comment = require_arg!(arguments, "comment")
      request_json(:post, "/api/v1/tasks/#{task_id}/comments", body: { "comment" => comment })
    end

    def get_daily_note(arguments)
      date = arguments["date"].presence || Date.current.iso8601
      request_json(:get, "/api/v1/daily_notes/#{date}")
    end

    def update_daily_note(arguments)
      date = arguments["date"].presence || Date.current.iso8601
      content = require_arg!(arguments, "content")
      request_json(:patch, "/api/v1/daily_notes/#{date}", body: { "content" => content })
    end

    def format_tool_result(name, result, arguments)
      case name
      when "missionbase_list_teams"
        format_list_teams(result)
      when "missionbase_get_current_user"
        format_get_current_user(result)
      when "missionbase_list_team_members"
        format_list_team_members(result, arguments)
      when "missionbase_list_team_boxes"
        format_list_team_boxes(result, arguments)
      when "missionbase_create_box"
        format_create_box(result)
      when "missionbase_list_tasks_visible_to_current_user"
        format_task_list_result(result, "Found %{count} visible tasks:")
      when "missionbase_list_tasks_assigned_to_current_user"
        format_task_list_result(result, "Found %{count} tasks assigned to current user:")
      when "missionbase_list_current_user_tasks_by_team"
        format_task_list_result(result, "Found %{count} tasks for current user in team #{arguments['team_id']}:")
      when "missionbase_list_tasks_by_box"
        format_task_list_result(result, "Found %{count} tasks in box #{arguments['box_id']}:")
      when "missionbase_list_active_tasks_by_team"
        format_task_list_result(result, "Found %{count} active tasks in team #{arguments['team_id']}:")
      when "missionbase_create_task"
        format_task_mutation(result, verb: "created")
      when "missionbase_update_task"
        format_task_mutation(result, verb: "updated")
      when "missionbase_get_task"
        format_get_task(result, include_entries: truthy?(arguments["include_entries"]))
      when "missionbase_assign_user_to_task"
        format_assignment_mutation(result, assigned: true)
      when "missionbase_unassign_user_from_task"
        format_assignment_mutation(result, assigned: false)
      when "missionbase_list_conversations"
        format_list_conversations(result)
      when "missionbase_get_conversation"
        format_get_conversation(result)
      when "missionbase_update_conversation_status"
        format_update_conversation_status(result)
      when "missionbase_add_comment_to_task"
        format_add_comment(result)
      when "missionbase_add_comment_to_conversation"
        format_add_comment(result)
      when "missionbase_get_daily_note"
        format_get_daily_note(result)
      when "missionbase_update_daily_note"
        format_update_daily_note(result)
      when "missionbase_search_notes"
        format_search_notes(result)
      else
        format_generic(result)
      end
    end

    def format_list_teams(result)
      teams = Array(result["teams"])
      lines = teams.map do |team|
        "• [ID: #{team['id']}] #{team['name']} (#{team['status'] || 'unknown'})"
      end
      join_lines("Found #{teams.count} teams:", lines)
    end

    def format_get_current_user(result)
      user = result["user"] || {}
      [
        "Current User Information:",
        "ID: #{user['id']}",
        "Name: #{user['name']}",
        "Email: #{user['email']}",
        "Username: #{user['username']}",
        "Account Type: #{user['account_type']}",
        "Time Zone: #{user['timezone']}",
        "Initials: #{user['initials']}"
      ].join("\n")
    end

    def format_list_team_members(result, arguments)
      members = Array(result["members"])
      lines = members.map do |m|
        "• [User ID: #{m['user_id']}] #{m['name']} (#{m['email']}) - Role: #{m['role']}, Status: #{m['status']}"
      end
      join_lines("Found #{members.count} members in team #{arguments['team_id']}:", lines)
    end

    def format_list_team_boxes(result, arguments)
      boxes = Array(result["boxes"])
      if arguments["status"].blank? && !truthy?(arguments["include_closed"])
        boxes = boxes.reject { |b| b["status"] == "closed" }
      end
      lines = boxes.map do |b|
        extras = [b['status'], b['visibility']].compact.join(", ")
        extras = " (#{extras})" if extras.present?
        "• [ID: #{b['id']}] #{b['name']}#{extras}"
      end
      join_lines("Found #{boxes.count} boxes in team #{arguments['team_id']}:", lines)
    end

    def format_create_box(result)
      box = result["box"] || {}
      [
        "Successfully created box: #{box['name']} (ID: #{box['id']})",
        ("Status: #{box['status']}" if box['status']),
        ("Visibility: #{box['visibility']}" if box['visibility'])
      ].compact.join("\n")
    end

    def format_task_list_result(result, header_template)
      tasks = Array(result["tasks"])
      lines = tasks.map do |task|
        box_name = task.dig("box", "name") || task["box"] || "No box"
        status = task["status"] || "unknown"
        title = task["title"] || "Untitled"
        do_on = task["do_on"]
        suffix = do_on.present? ? " [#{do_on}]" : ""
        assignees = extract_assignee_names(task)
        assignee_suffix = assignees.any? ? " [#{assignees.join(', ')}]" : ""
        "• [ID: #{task['id']}] #{title} (#{status}) - #{box_name}#{suffix}#{assignee_suffix}"
      end
      join_lines(format(header_template, count: tasks.count), lines)
    end

    def format_task_mutation(result, verb:)
      task = result["task"] || {}
      title = task['title'] || 'Task'
      id = task['id']
      line = "Successfully #{verb} task: #{title}"
      line += " (ID: #{id})" if id
      line
    end

    def format_get_task(result, include_entries: false)
      task = result["task"] || {}
      lines = []
      lines << "Task Details:"
      lines << "ID: #{task['id']}"
      lines << "Title: #{task['title']}"
      lines << "Status: #{task['status']}"
      lines << "Box: #{task.dig('box', 'name') || 'No box'}"
      lines << "Created by: #{task.dig('created_by', 'name')}" if task['created_by'].is_a?(Hash)
      lines << "Do on: #{task['do_on'] || 'Not scheduled'}"
      lines << "Deadline: #{task['deadline'] || 'No deadline'}"
      lines << "Created: #{task['created_at']}" if task['created_at']
      lines << "Updated: #{task['updated_at']}" if task['updated_at']
      if task['description'].present?
        desc = task['description'].to_s.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip
        lines << "Description: #{desc}" if desc.present?
      end
      assignees = extract_assignee_names(task)
      lines << (assignees.any? ? "Assigned to: #{assignees.join(', ')}" : "Assigned to: No assignments")
      lines << "\nNote: include_entries is not supported by the REST-backed plugin transport." if include_entries
      lines.join("\n")
    end

    def format_assignment_mutation(result, assigned:)
      if assigned
        assignment = result["assignment"] || {}
        user = assignment["user"] || {}
        "Successfully assigned #{user['name'] || "user #{user['id']}"} to task ID #{assignment['task_id']}"
      else
        result["message"].presence || "Successfully removed assignment"
      end
    end

    def format_list_conversations(result)
      conversations = Array(result["conversations"])
      lines = conversations.map do |c|
        box_name = c.dig("box", "name") || "No box"
        preview = c["preview"].to_s.strip
        base = "• [ID: #{c['id']}] #{c['title']} (#{c['status']}) - #{box_name}"
        preview.present? ? "#{base}\n  #{preview}" : base
      end
      join_lines("Found #{conversations.count} conversations:", lines, double: true)
    end

    def format_get_conversation(result)
      c = result["conversation"] || {}
      entries = Array(c["entries"])
      header = [
        "Conversation Details:",
        "ID: #{c['id']}",
        "Title: #{c['title']}",
        "Type: #{c['type']}",
        "Status: #{c['status']}",
        "Box: #{c.dig('box', 'name') || 'No box'}"
      ]
      if entries.any?
        entry_lines = entries.map do |e|
          who = e.dig('user', 'name') || e['user_name'] || 'Unknown'
          kind = e['entry_type'] || e['type'] || 'entry'
          content = extract_entry_text(e)
          time = e['created_at'] || e['updated_at']
          [time, who, kind, content].compact.join(' - ')
        end
        (header + ["", "Recent Entries:"] + entry_lines).join("\n")
      else
        (header + ["", "Recent Entries: none"]).join("\n")
      end
    end

    def format_update_conversation_status(result)
      c = result["conversation"] || {}
      "Successfully updated conversation #{c['id']} status to #{c['status']}"
    end

    def format_add_comment(result)
      if result["comment"].is_a?(Hash)
        comment = result["comment"]
        "Successfully added comment (ID: #{comment['id']})"
      else
        format_generic(result)
      end
    end

    def format_get_daily_note(result)
      note = result["daily_note"] || {}
      content = note["content"]
      date = note["date"] || "(unknown date)"
      if content.present?
        plain = content.to_s.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip
        "Daily Note for #{date}:\n\n#{plain.presence || '(empty)'}"
      else
        note["message"].presence || "No daily note exists for #{date}"
      end
    end

    def format_update_daily_note(result)
      note = result["daily_note"] || {}
      "Successfully updated daily note for #{note['date'] || Date.current.iso8601}"
    end

    def format_search_notes(result)
      notes = Array(result["notes"])
      if notes.empty?
        "No notes found"
      else
        lines = notes.map do |n|
          "• [#{n['type'].to_s.upcase}] #{n['title']} (#{n['subtitle'] || 'No box'})\n  #{n['preview']}"
        end
        join_lines("Found #{notes.count} notes:", lines, double: true)
      end
    end

    def format_generic(result)
      JSON.pretty_generate(result)
    rescue JSON::GeneratorError
      result.to_s
    end

    def join_lines(header, lines, double: false)
      return header if lines.empty?
      separator = double ? "\n\n" : "\n"
      "#{header}\n\n#{lines.join(separator)}"
    end

    def extract_assignee_names(task)
      list = task["assignees"] || task["assignments"] || []
      Array(list).map do |entry|
        if entry.is_a?(Hash)
          entry["name"] || entry["full_name"]
        else
          entry.to_s
        end
      end.compact
    end

    def extract_entry_text(entry)
      text = entry["content"] || entry["body"] || entry.dig("comment", "content")
      text.to_s.gsub(/<[^>]+>/, ' ').gsub(/\s+/, ' ').strip
    end

    def normalize_arguments(arguments)
      (arguments || {}).to_h.deep_stringify_keys
    end

    def ensure_team_id!(name, arguments)
      raise ToolArgumentError, "#{name} requires team_id" if arguments["team_id"].blank?
    end

    def ensure_configured!
      if missionbase_api_key.blank?
        raise ToolArgumentError, "MISSIONBASE_API_KEY is not configured for this agent. Set it in Agent > Plugins > missionbase > Configure."
      end
    end

    def require_arg!(arguments, key)
      value = arguments[key]
      raise ToolArgumentError, "#{key} is required" if value.blank?

      value
    end

    def pick_identifier(arguments, *keys)
      keys.each do |key|
        value = arguments[key]
        return value if value.present?
      end
      raise ToolArgumentError, "#{keys.join(' or ')} is required"
    end

    def request_json(method, path, query: nil, body: nil)
      response = perform_request(method, path, query: query, body: body)
      parse_json_response(response)
    end

    def perform_request(method, path, query: nil, body: nil)
      uri = build_uri(path, query)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 20

      request = build_request(method, uri, body)
      response = http.request(request)
      return response if response.code.to_i.between?(200, 299)

      raise ApiError, api_error_message(response)
    end

    def build_request(method, uri, body)
      request_class = case method.to_sym
      when :get then Net::HTTP::Get
      when :post then Net::HTTP::Post
      when :patch then Net::HTTP::Patch
      when :delete then Net::HTTP::Delete
      else
        raise ToolArgumentError, "unsupported HTTP method: #{method}"
      end

      request = request_class.new(uri)
      request["Authorization"] = "Bearer #{missionbase_api_key}"
      request["User-Agent"] = USER_AGENT
      JSON_HEADERS.each { |key, value| request[key] = value }
      request.body = JSON.generate(compact_hash(body)) if body.present?
      request
    end

    def build_uri(path, query)
      base = normalized_base_url
      uri = URI.parse("#{base}#{path}")
      encoded = encode_query(query)
      uri.query = encoded if encoded.present?
      uri
    end

    def normalized_base_url
      BASE_URL
    end

    def encode_query(query)
      return nil if query.blank?

      pairs = []
      compact_hash(query).each do |key, value|
        if value.is_a?(Array)
          value.each { |entry| pairs << [ key, entry ] }
        else
          pairs << [ key, value ]
        end
      end
      URI.encode_www_form(pairs)
    end

    def parse_json_response(response)
      body = response.body.to_s
      return {} if body.blank?

      JSON.parse(body)
    end

    def api_error_message(response)
      parsed = JSON.parse(response.body.to_s)
      message = if parsed.is_a?(Hash)
        error_value = parsed["error"]
        if error_value.is_a?(Hash)
          error_value["message"]
        elsif error_value.present?
          error_value.to_s
        else
          parsed["message"]
        end
      else
        parsed.to_s
      end
      "HTTP #{response.code}: #{message || response.body.to_s.truncate(300)}"
    rescue JSON::ParserError
      "HTTP #{response.code}: #{response.body.to_s.truncate(300)}"
    end

    def current_missionbase_user_id
      @current_missionbase_user_id ||= begin
        response = request_json(:get, "/api/v1/users/me")
        user_value = response.is_a?(Hash) ? response["user"] : nil
        user_id = user_value.is_a?(Hash) ? user_value["id"] : nil
        user_id || raise(ToolArgumentError, "Missionbase users/me response did not include user.id")
      end
    end

    def missionbase_api_key
      plugin.resolve_config("MISSIONBASE_API_KEY", agent: @agent)
    end

    def plugin
      @plugin ||= @agent.account.plugins.find_by!(name: "missionbase")
    end

    def slice(hash, *keys)
      keys.each_with_object({}) do |key, result|
        result[key] = hash[key] if hash.key?(key)
      end
    end

    def compact_hash(hash)
      (hash || {}).each_with_object({}) do |(key, value), result|
        next if value.nil?
        next if value.respond_to?(:empty?) && value.empty?

        result[key] = value
      end
    end

    def truthy?(value)
      value == true || value.to_s == "true"
    end

    def optional_positive_integer(value, key:)
      return nil if value.nil? || value == ""

      parsed = Integer(value)
      return nil if parsed.zero?
      raise ToolArgumentError, "#{key} must be a positive integer" if parsed.negative?

      parsed
    rescue ArgumentError, TypeError
      raise ToolArgumentError, "#{key} must be a positive integer"
    end
end
