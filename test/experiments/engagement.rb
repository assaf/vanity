usage "Engagement" do
  measure do
    { "Stories"=> (1..28).inject([]) { |a,i| a << [Date.today - 28 + i, a.last ? a.last.last * (1.0 + rand * 0.1) : 200] },
      "Comments"=> (1..28).inject([]) { |a,i| a << [Date.today - 28 + i, a.last ? a.last.last * (1.0 + rand * 0.2) : 150] } }
  end

  def Time.now ; Time.at(Time.new.to_i - 15 * 60 * 60 * 24) ; end
  milestone "New bookmarklet"
  def Time.now ; Time.at(Time.new.to_i - 5 * 60 * 60 * 24) ; end
  milestone "New moderation tool"
  def Time.now ; Time.at(Time.new.to_i) ; end

end
