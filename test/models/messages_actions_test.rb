require './test/test_helper'

# testing Messages::Actions
class MessagesActionsTest < ActiveSupport::TestCase

  # this method is used to fix the rubbish input from list regexes
  def test_munge_list
    # single string is converted to one-member array
    assert_equal(
      ['this'],
      Messages::Actions.munge_list('this')
    )

    assert_equal(
      ['this', 'that', 'theother'],
      Messages::Actions.munge_list(['this', ', that', 'that', ' and theother'])
    )
  end

  def test_pattern_not_found
    result = Messages::Actions.pattern_not_found(['timpani', 'guitar'])
    assert_equal 'failure', result[:response]
    assert_equal(
      "Sorry, I can't find any patterns named timpani and guitar",
      result[:display]
    )
  end


  def test_add_steps_one_step
    result = Messages::Actions.add_steps(
      {
        'pattern_name' => 'kick',
        'steps' => ['3']
      }
    )
    assert_equal 'success', result[:response]
    assert_equal "Now playing kick on step 3", result[:display]

    pattern = Pattern.find_by_name('kick')
    assert_equal(
      [2],
      pattern.pattern_indexes
    )
  end

  def test_add_steps_out_of_range
    result = Messages::Actions.add_steps(
      {
        'pattern_name' => 'kick',
        'steps' => ['92','93','94']
      }
    )
    assert_equal 'failure', result[:response]
    assert_equal(
      "Sorry, I can't add these steps because some are out of range (1 to 32)",
      result[:display]
    )
  end

  def test_add_steps_no_pattern
    result = Messages::Actions.add_steps(
      {
        'pattern_name' => 'tabla',
        'steps' => ['3']
      }
    )
    assert_equal 'failure', result[:response]
    assert_equal "Sorry, I can't find any patterns named tabla", result[:display]
  end

  def test_add_steps_list
    result = Messages::Actions.add_steps(
      {
        'pattern_name' => 'kick',
        'steps' => ['3','9','14']
      }
    )
    assert_equal 'success', result[:response]
    assert_equal "Now playing kick on steps 3, 9 and 14", result[:display]

    pattern = Pattern.find_by_name('kick')
    assert_equal(
      [2,8,13],
      pattern.pattern_indexes
    )
  end

  def test_add_steps_block
    result = Messages::Actions.add_steps(
      {
        'pattern_name' => 'kick',
        'start_step' => '3',
        'end_step' => '7'
      }
    )
    assert_equal 'success', result[:response]
    assert_equal "Now playing kick on steps 3, 4, 5, 6 and 7", result[:display]

    pattern = Pattern.find_by_name('kick')
    assert_equal(
      [2,3,4,5,6],
      pattern.pattern_indexes
    )
  end

  def test_add_steps_block_with_skipping
    result = Messages::Actions.add_steps(
      {
        'pattern_name' => 'kick',
        'start_step' => '3',
        'end_step' => '7',
        'block_size' => '1'
      }
    )
    assert_equal 'success', result[:response]
    assert_equal "Now playing kick on steps 3, 5 and 7", result[:display]

    pattern = Pattern.find_by_name('kick')
    assert_equal(
      [2,4,6],
      pattern.pattern_indexes
    )
  end

  def test_clear_all_drums
    Pattern.first.update_attribute :pattern_indexes, [0,1,2]
    Pattern.last.update_attribute :pattern_indexes, [0,1,2]

    result = Messages::Actions.clear_all_drums({})
    assert_equal 'success', result[:response]
    assert_equal("I've cleared all of the drum patterns.", result[:display])
  end

  def test_clear_patterns_one
    result = Messages::Actions.clear_patterns({'pattern_names' => ['kick']})
    assert_equal 'success', result[:response]
    assert_equal("I've cleared the kick pattern", result[:display])
  end

  def test_clear_patterns_list
    result = Messages::Actions.clear_patterns({'pattern_names' => ['kick', 'snare', 'hihat']})
    assert_equal 'success', result[:response]
    assert_equal("I've cleared the kick, snare and hihat patterns", result[:display])
  end

  def test_clear_patterns_no_pattern
    result = Messages::Actions.clear_patterns({'pattern_names' => ['dog','cat','fridge']})
    assert_equal 'failure', result[:response]
    assert_equal "Sorry, I can't find any patterns named dog, cat and fridge", result[:display]
  end

  def test_clear_steps_one
    Pattern.first.update_attribute :pattern_indexes, [0,1,2,3,4,5,6]

    result = Messages::Actions.clear_steps(
      {
        'pattern_name' => 'kick',
        'steps' => ['1']
      }
    )
    assert_equal 'success', result[:response]
    assert_equal(
      "Now no longer playing kick on step 1",
      result[:display]
    )
    pattern = Pattern.find_by_name('kick')
    assert_equal(
      [1,2,3,4,5,6],
      pattern.pattern_indexes
    )
  end


  def test_clear_steps_out_of_range
    result = Messages::Actions.clear_steps(
      {
        'pattern_name' => 'kick',
        'steps' => ['92','93','94']
      }
    )
    assert_equal 'failure', result[:response]
    assert_equal(
      "Sorry, I can't clear these steps because some are out of range (1 to 32)",
      result[:display]
    )
  end

  def test_clear_steps_no_pattern
    result = Messages::Actions.clear_steps(
      {
        'pattern_name' => 'tabla',
        'steps' => ['3']
      }
    )
    assert_equal 'failure', result[:response]
    assert_equal "Sorry, I can't find any patterns named tabla", result[:display]
  end

  def test_clear_steps_list
    Pattern.first.update_attribute :pattern_indexes, [0,1,2,3,4,5,6]

    result = Messages::Actions.clear_steps(
      {
        'pattern_name' => 'kick',
        'steps' => ['3','5','6']
      }
    )
    assert_equal 'success', result[:response]
    assert_equal "Now no longer playing kick on steps 3, 5 and 6", result[:display]

    pattern = Pattern.find_by_name('kick')
    assert_equal(
      [0,1,3,6],
      pattern.pattern_indexes
    )
  end

  def test_clear_steps_block
    Pattern.first.update_attribute :pattern_indexes, [0,1,2,3,4,5,6]

    result = Messages::Actions.clear_steps(
      {
        'pattern_name' => 'kick',
        'start_step' => '2',
        'end_step' => '4'
      }
    )
    assert_equal 'success', result[:response]
    assert_equal "Now no longer playing kick on steps 2, 3 and 4", result[:display]

    pattern = Pattern.find_by_name('kick')
    assert_equal(
      [0,4,5,6],
      pattern.pattern_indexes
    )
  end

  def test_clear_steps_block_with_skipping
    Pattern.first.update_attribute :pattern_indexes, [0,1,2,3,4,5,6]
    result = Messages::Actions.clear_steps(
      {
        'pattern_name' => 'kick',
        'start_step' => '3',
        'end_step' => '7',
        'block_size' => '1'
      }
    )
    assert_equal 'success', result[:response]
    assert_equal "Now no longer playing kick on steps 3, 5 and 7", result[:display]

    pattern = Pattern.find_by_name('kick')
    assert_equal(
      [0,1,3,5],
      pattern.pattern_indexes
    )
  end

  def test_list_drums
    result = Messages::Actions.list_drums({})
    assert_equal 'success', result[:response]
    assert_equal(
      "* kick
* snare
* hihat
* crash
* tom1
* tom2
* tom3
",
      result[:display]
    )

  end

  def test_mute_one
    pattern = Pattern.where(:name => 'kick').first

    result = Messages::Actions.mute_unmute(
      {
        'pattern_names' => ['kick'],
        'mode' => 'mute'
      }
    )
    assert_equal 'success', result[:response]
    assert_equal(
      "I've muted the kick pattern",
      result[:display]
    )

    pattern.reload
    assert_equal true, pattern.muted
  end

  def test_mute_list
    patterns = Pattern.where(:name => ['kick','snare','hihat'])

    result = Messages::Actions.mute_unmute(
      {
        'pattern_names' => ['kick', 'snare', 'hihat'],
        'mode' => 'mute'
      }
    )
    assert_equal 'success', result[:response]
    assert_equal(
      "I've muted the kick, snare and hihat patterns",
      result[:display]
    )

    patterns.each do |pattern|
      assert_equal true, pattern.muted
    end
  end

  def test_unmute_one
    pattern = Pattern.where(:name => 'kick').first
    pattern.update_attribute(:muted, true)

    result = Messages::Actions.mute_unmute(
      {
        'pattern_names' => ['kick'],
        'mode' => 'unmute'
      }
    )
    assert_equal 'success', result[:response]
    assert_equal(
      "I've unmuted the kick pattern",
      result[:display]
    )

    pattern.reload
    assert_equal false, pattern.muted
  end

  def test_unmute_list
    patterns = Pattern.where(:name => ['kick','snare','hihat'])
    patterns.each{|pattern| pattern.update_attribute :muted, true}


    result = Messages::Actions.mute_unmute(
      {
        'pattern_names' => ['kick', 'snare', 'hihat'],
        'mode' => 'unmute'
      }
    )
    assert_equal 'success', result[:response]
    assert_equal(
      "I've unmuted the kick, snare and hihat patterns",
      result[:display]
    )

    patterns.each do |pattern|
      pattern.reload
      assert_equal false, pattern.muted
    end
  end

  def test_set_speed
    result = Messages::Actions.set_speed(
      {'bpm' => ['150']}
    )
    assert_equal 'success', result[:response]
    assert_equal(
      "The speed is now 150 beats per minute",
      result[:display]
    )
    assert_equal '150', SystemSetting['bpm']
  end

  def test_set_speed_too_fast
    result = Messages::Actions.set_speed(
      {'bpm' => ['900']}
    )
    assert_equal 'failure', result[:response]
    assert_equal(
      "Sorry, the speed you asked for (900 bpm) is more than the maximum: 200 bpm",
      result[:display]
    )
  end

  def test_set_speed_too_slow
    result = Messages::Actions.set_speed(
      {'bpm' => ['1']}
    )
    assert_equal 'failure', result[:response]
    assert_equal(
      "Sorry, the speed you asked for (1 bpm) is less than the minimum: 60 bpm",
      result[:display]
    )
  end


  def test_speed_up
    SystemSetting['bpm'] = 120
    result = Messages::Actions.speed_up({})
    assert_equal 'success', result[:response]
    assert_equal(
      "The speed is now 125 beats per minute",
      result[:display]
    )

    result = Messages::Actions.speed_up({})
    assert_equal 'success', result[:response]
    assert_equal(
      "The speed is now 130 beats per minute",
      result[:display]
    )
  end

  def test_speed_down
    SystemSetting['bpm'] = 120
    result = Messages::Actions.speed_down({})
    assert_equal 'success', result[:response]
    assert_equal(
      "The speed is now 115 beats per minute",
      result[:display]
    )

    result = Messages::Actions.speed_down({})
    assert_equal 'success', result[:response]
    assert_equal(
      "The speed is now 110 beats per minute",
      result[:display]
    )
  end

  def test_show_speed
    SystemSetting['bpm'] = 120
    result = Messages::Actions.show_speed({})
    assert_equal 'success', result[:response]
    assert_equal(
      "The speed is 120 beats per minute",
      result[:display]
    )
  end

  def test_show_one_pattern
    result = Messages::Actions.show_patterns(
      {'pattern_names' => ['kick']}
    )
    display = "-----1---5---9---13--17--21--25--29--
kick---------------------------------
"
    assert_equal(
      display,
      result[:display]
    )
  end

  def test_show_list
    def test_show_one_pattern
      result = Messages::Actions.show_patterns(
        {'pattern_names' => ['kick','snare','hihat']}
      )
      display = "------1---5---9---13--17--21--25--29--
kick----------------------------------
snare---------------------------------
hihat---------------------------------
"
      assert_equal(
        display,
        result[:display]
      )
    end

  end



end
