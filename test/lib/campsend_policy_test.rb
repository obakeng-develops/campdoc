require "test_helper"

class CampsendPolicyTest < ActiveSupport::TestCase
  test "default policy admits storage and deliveries" do
    policy = Campsend::Policy.new

    assert_equal :stored, policy.admit_storage(user: Object.new, byte_size: 1) { :stored }
    assert_equal :sent, policy.admit_delivery(user: Object.new) { :sent }
  end

  test "default policy has no usage UI or extra telemetry" do
    policy = Campsend::Policy.new

    assert_nil policy.usage_for(Object.new)
    assert_empty policy.telemetry_for(Object.new)
  end

  test "denial exposes a safe outcome and message" do
    error = Campsend::Policy::Denied.new("Limit reached.", outcome: "limit")

    assert_equal "limit", error.outcome
    assert_equal "Limit reached.", error.message
  end
end
