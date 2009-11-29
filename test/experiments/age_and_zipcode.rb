ab_test "Age and Zipcode" do
  description <<-TEXT
Testing new registration form that asks for age and zipcode. Option A presents
the existing form, and option B adds age and zipcode fields.
   
We know option B will convert less, but higher quality leads. If we lose less
than 20% conversions, we're going to switch to option B.
  TEXT
  metrics :signups

  complete_if do
    alternatives.all? { |alt| alt.participants > 100 }
  end
  outcome_is do
    one_field = alternative(false)
    three_fields = alternative(true)
    three_fields.conversion_rate >= 0.8 * one_field.conversion_rate ? three_fields : one_field
  end
end
