ab_test "Null/ABC" do
  description "Testing three alternatives"
  alternatives nil, :red, :green, :blue
  metrics :signups
end
