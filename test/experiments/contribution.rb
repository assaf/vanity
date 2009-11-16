usage "Contribution" do
  description "Measuring user contribution against new features."

  self.created_at = Date.today - 25
  milestone "New bookmarklet", Date.today - 15
  milestone "New moderation tool", Date.today - 5

  measure do |from, to|
    { "Stories"=> (from..to).inject([]) { |a,date| a << [date, a.last ? a.last.last * (1.0 + rand * 0.1) : 200] },
      "Comments"=> (from..to).inject([]) { |a,date| a << [date, a.last ? a.last.last * (1.0 + rand * 0.2) : 150] } }
  end
end
