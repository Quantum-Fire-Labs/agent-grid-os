class ScheduledAction::NextRunCalculation
  DAY_INDEX = {
    "sun" => 0,
    "mon" => 1,
    "tue" => 2,
    "wed" => 3,
    "thu" => 4,
    "fri" => 5,
    "sat" => 6
  }.freeze

  attr_reader :action

  def initialize(action)
    @action = action
  end

  def next_run_at(reference_time: Time.current)
    return nil if action.canceled? || action.completed?

    if action.once?
      return nil if action.one_time_run_at.blank?
      return nil if action.ends_at.present? && action.one_time_run_at > action.ends_at

      return action.one_time_run_at
    end

    next_recurring_run_at(reference_time: reference_time)
  end

  private
    def next_recurring_run_at(reference_time:)
      recurrence = ScheduledAction::Recurrence.new(action.recurrence_rule)
      tz = time_zone
      base = [ reference_time, action.starts_at ].compact.max
      local_base = base.in_time_zone(tz)

      candidate =
        case recurrence.frequency
        when "daily" then next_daily(local_base, recurrence)
        when "weekly" then next_weekly(local_base, recurrence)
        when "monthly" then next_monthly(local_base, recurrence)
        end

      return nil if candidate.blank?

      utc_candidate = candidate.utc
      return nil if action.ends_at.present? && utc_candidate > action.ends_at

      utc_candidate
    end

    def next_daily(local_base, recurrence)
      hour, min = parse_time_of_day(recurrence.time_of_day)
      start_local = (action.starts_at || local_base).in_time_zone(time_zone)
      anchor_date = start_local.to_date
      base_date = local_base.to_date
      days_since_anchor = (base_date - anchor_date).to_i
      interval = recurrence.interval
      step_days = if days_since_anchor.negative?
        0
      else
        (days_since_anchor / interval) * interval
      end

      date = anchor_date + step_days
      loop do
        candidate = local_time(date, hour, min)
        return candidate if candidate > local_base && candidate >= start_local

        date += interval
      end
    end

    def next_weekly(local_base, recurrence)
      hour, min = parse_time_of_day(recurrence.time_of_day)
      start_local = (action.starts_at || local_base).in_time_zone(time_zone)
      start_week_start = start_local.to_date - start_local.wday
      base_week_start = local_base.to_date - local_base.wday
      weeks_since_anchor = ((base_week_start - start_week_start).to_i / 7.0).floor
      interval = recurrence.interval
      week_step = if weeks_since_anchor.negative?
        0
      else
        (weeks_since_anchor / interval) * interval
      end

      allowed_days = recurrence.days_of_week.map { |d| DAY_INDEX.fetch(d) }.sort
      week_start = start_week_start + (week_step * 7)

      loop do
        allowed_days.each do |wday|
          date = week_start + wday
          candidate = local_time(date, hour, min)
          next if candidate < start_local
          return candidate if candidate > local_base
        end

        week_start += interval * 7
      end
    end

    def next_monthly(local_base, recurrence)
      hour, min = parse_time_of_day(recurrence.time_of_day)
      start_local = (action.starts_at || local_base).in_time_zone(time_zone)
      interval = recurrence.interval
      target_day = recurrence.day_of_month
      year = start_local.year
      month = start_local.month

      loop do
        if Date.valid_date?(year, month, target_day)
          date = Date.new(year, month, target_day)
          candidate = local_time(date, hour, min)
          if candidate >= start_local && candidate > local_base
            return candidate
          end
        end

        year, month = advance_month(year, month, interval)
      end
    end

    def local_time(date, hour, min)
      time_zone.local(date.year, date.month, date.day, hour, min, 0)
    end

    def parse_time_of_day(value)
      hour_s, min_s = value.split(":", 2)
      [ hour_s.to_i, min_s.to_i ]
    end

    def time_zone
      @time_zone ||= ActiveSupport::TimeZone[action.timezone] || ActiveSupport::TimeZone["UTC"]
    end

    def advance_month(year, month, interval)
      total = (year * 12 + (month - 1)) + interval
      [ total / 12, (total % 12) + 1 ]
    end
end
