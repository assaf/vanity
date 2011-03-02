require "test/test_helper"

class PlaygroundTest < Test::Unit::TestCase

  def test_has_one_global_instance
    assert instance = Vanity.playground
    assert_equal instance, Vanity.playground
  end
  
  def test_redis_experiments_namespace_includes_app_name
    not_collecting!
    new_ab_test :simple do
      alternatives :a, :b, :c
    end
    experiments = Vanity.playground.instance_variable_get('@adapter').instance_variable_get('@experiments')
    full_namespace = experiments.instance_variable_get('@namespace')
    app_name_part = full_namespace.split(":").first
    assert_equal File.basename(RAILS_ROOT), app_name_part
  end
  
  def test_redis_metrics_namespace_includes_app_name
    not_collecting!
    new_ab_test :simple do
      alternatives :a, :b, :c
    end
    metrics = Vanity.playground.instance_variable_get('@adapter').instance_variable_get('@metrics')
    full_namespace = metrics.instance_variable_get('@namespace')
    app_name_part = full_namespace.split(":").first
    assert_equal File.basename(RAILS_ROOT), app_name_part
  end
end
