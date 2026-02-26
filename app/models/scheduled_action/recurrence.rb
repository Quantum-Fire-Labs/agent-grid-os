class ScheduledAction::Recurrence
  DAY_NAMES = %w[mon tue wed thu fri sat sun].freeze

  attr_reader :rule

  def initialize(rule)
    @rule = (rule || {}).deep_stringify_keys
  end

  def frequency
    rule["frequency"].to_s
  end

  def interval
    (rule["interval"] || 1).to_i
  end

  def time_of_day
    rule["time_of_day"].to_s
  end

  def days_of_week
    Array(rule["days_of_week"]).map(&:to_s)
  end

  def day_of_month
    return nil if rule["day_of_month"].blank?

    rule["day_of_month"].to_i
  end

  def validate(errors)
    unless %w[daily weekly monthly].include?(frequency)
      errors.add(:recurrence_rule, "frequency must be daily, weekly, or monthly")
      return
    end

    errors.add(:recurrence_rule, "interval must be >= 1") if interval < 1
    errors.add(:recurrence_rule, "time_of_day must be HH:MM") unless time_of_day.match?(/\A\d{2}:\d{2}\z/)
    if time_of_day.match?(/\A\d{2}:\d{2}\z/)
      hour, min = time_of_day.split(":").map(&:to_i)
      errors.add(:recurrence_rule, "time_of_day must be a valid 24-hour time") if !(0..23).cover?(hour) || !(0..59).cover?(min)
    end

    case frequency
    when "weekly"
      if days_of_week.empty?
        errors.add(:recurrence_rule, "days_of_week is required for weekly recurrence")
      elsif (days_of_week - DAY_NAMES).any?
        errors.add(:recurrence_rule, "days_of_week contains invalid values")
      end
    when "monthly"
      if day_of_month.blank?
        errors.add(:recurrence_rule, "day_of_month is required for monthly recurrence")
      elsif !(1..31).cover?(day_of_month)
        errors.add(:recurrence_rule, "day_of_month must be between 1 and 31")
      end
    end
  end
end
