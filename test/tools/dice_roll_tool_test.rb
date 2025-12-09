require "test_helper"

class DiceRollToolTest < ActiveSupport::TestCase
  def setup
    @rng = Random.new(1234)
    @tool = DiceRollTool.new(rng: @rng)
  end

  test "schema returns valid OpenAI function format" do
    schema = DiceRollTool.schema

    assert_equal "function", schema[:type]
    assert_equal "dice_roll", schema[:function][:name]
    assert_includes %w[normal advantage disadvantage], schema[:function][:parameters][:properties][:mode][:enum].first
  end

  test "roll single die" do
    result = @tool.execute(dice: "d6")

    assert result[:success]
    assert_equal "normal", result[:result][:mode]
    assert_equal 1, result[:result][:rolls].size
    assert result[:result][:total] >= 1
  end

  test "roll multiple dice with modifier" do
    result = @tool.execute(dice: "2d6", modifier: 3)

    assert result[:success]
    assert_equal 2, result[:result][:rolls].size
    assert_equal result[:result][:rolls].sum + 3, result[:result][:total]
  end

  test "advantage uses highest of two d20 rolls" do
    result = @tool.execute(dice: "d20", mode: "advantage", modifier: 2)

    assert result[:success]
    rolls = result[:result][:rolls]
    assert_equal 2, rolls.size
    assert_equal rolls.max + 2, result[:result][:total]
    assert_equal rolls.max, result[:result][:kept]
  end

  test "disadvantage uses lowest of two d20 rolls" do
    result = @tool.execute(dice: "1d20", mode: "disadvantage")

    assert result[:success]
    rolls = result[:result][:rolls]
    assert_equal rolls.min, result[:result][:kept]
  end

  test "rejects invalid dice string" do
    result = @tool.execute(dice: "abc")

    refute result[:success]
    assert_includes result[:error], "Invalid dice format"
  end

  test "rejects excessive dice count" do
    result = @tool.execute(dice: "50d6")

    refute result[:success]
    assert_includes result[:error], "between 1 and"
  end

  test "rejects advantage for non d20" do
    result = @tool.execute(dice: "2d6", mode: "advantage")

    refute result[:success]
    assert_includes result[:error], "single d20"
  end
end
