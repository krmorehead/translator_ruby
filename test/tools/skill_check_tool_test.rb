require "test_helper"

class SkillCheckToolTest < ActiveSupport::TestCase
  def setup
    @rng_seed = 4567
  end

  def new_tool
    SkillCheckTool.new(rng: Random.new(@rng_seed))
  end

  test "performs skill check with dc and proficiency" do
    ability = 2
    proficiency = 3
    dc = 12

    # Expected roll with deterministic RNG
    expected_roll = Random.new(@rng_seed).random_number(20) + 1
    expected_total = expected_roll + ability + proficiency
    expected_success = expected_total >= dc

    tool = new_tool
    result = tool.execute(skill: "Perception", ability_modifier: ability, proficiency_bonus: proficiency, dc: dc)

    assert result[:success]
    payload = result[:result]
    assert_equal expected_total, payload[:total]
    assert_equal expected_success, payload[:success]
    assert_equal dc, payload[:dc]
    assert_equal ability, payload[:ability_modifier]
    assert_equal proficiency, payload[:proficiency_bonus]
    assert_equal "normal", payload[:mode]
    assert_equal "Perception", payload[:skill]
  end

  test "advantage path uses highest roll" do
    ability = 1
    proficiency = 0

    rng = Random.new(@rng_seed)
    roll1 = rng.random_number(20) + 1
    roll2 = rng.random_number(20) + 1
    kept = [roll1, roll2].max
    expected_total = kept + ability + proficiency

    tool = SkillCheckTool.new(rng: Random.new(@rng_seed))
    result = tool.execute(skill: "Stealth", ability_modifier: ability, proficiency_bonus: proficiency, mode: "advantage")

    assert result[:success]
    payload = result[:result]
    assert_equal expected_total, payload[:total]
    assert_equal kept, payload[:dice][:kept]
    assert_equal [roll1, roll2].sort, payload[:dice][:rolls].sort
    assert_equal "advantage", payload[:mode]
  end

  test "disadvantage path uses lowest roll" do
    rng = Random.new(@rng_seed)
    roll1 = rng.random_number(20) + 1
    roll2 = rng.random_number(20) + 1
    kept = [roll1, roll2].min

    tool = SkillCheckTool.new(rng: Random.new(@rng_seed))
    result = tool.execute(skill: "Athletics", ability_modifier: 0, proficiency_bonus: 0, mode: "disadvantage")

    assert result[:success]
    payload = result[:result]
    assert_equal kept, payload[:dice][:kept]
    assert_equal "disadvantage", payload[:mode]
  end

  test "handles missing dc (success nil)" do
    tool = new_tool
    result = tool.execute(skill: "History", ability_modifier: 0, proficiency_bonus: 0)

    assert result[:success]
    payload = result[:result]
    assert_nil payload[:success]
    assert_nil payload[:dc]
  end

  test "propagates error from dice tool" do
    tool = SkillCheckTool.new(rng: Random.new(@rng_seed))

    # Force dice tool error by passing invalid mode
    result = tool.execute(skill: "Stealth", ability_modifier: 0, proficiency_bonus: 0, mode: "invalid")

    refute result[:success]
    assert_includes result[:error], "Invalid"
  end
end
