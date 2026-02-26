module Agent::Tools::SchedulingParams
  private
    def scheduling_user
      sender = context[:user_message_record]&.sender
      return sender if sender.is_a?(User)

      return unless context[:chat]

      msg = context[:chat].messages.where(role: "user").order(:created_at).last
      sender = msg&.sender
      sender if sender.is_a?(User)
    end

    def effective_timezone(argument_timezone)
      tz = argument_timezone.presence || scheduling_user&.time_zone.presence || "UTC"
      raise ArgumentError, "Invalid timezone: #{tz}" unless ActiveSupport::TimeZone[tz]

      tz
    end

    def current_chat
      context[:chat]
    end

    def parse_schedule!(scheduled_action, timezone:)
      scheduled_action.timezone = timezone
      scheduled_action.apply_schedule(arguments.fetch("schedule"))
    rescue KeyError
      raise ArgumentError, "schedule is required"
    end
end
