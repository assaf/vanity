class Time
  unless method_defined?(:to_date)
    # Backported from Ruby 1.9.
    def to_date
      jd = Date.__send__(:civil_to_jd, year, mon, mday, Date::ITALY)
      Date.new!(Date.__send__(:jd_to_ajd, jd, 0, 0), 0, Date::ITALY)
    end
  end
end

class Date
  unless method_defined?(:to_date)
    # Backported from Ruby 1.9.
    def to_date
      self
    end
  end

  unless method_defined?(:to_time)
    # Backported from Ruby 1.9.
    def to_time
      Time.local(year, mon, mday)
    end
  end
end
