
#
# testing ruote
#
# Fri May 13 14:12:52 JST 2011
#

require File.expand_path('../../test_helper', __FILE__)

module Ruote; end
require 'ruote/exp/merge'


class MergeTest < Test::Unit::TestCase

  class Merger
    include Ruote::Exp::MergeMixin

    def expand_atts
      nil
    end
  end

  def new_workitem(fields)

    { 'fields' => fields }
  end

  def new_workitems

    [
      new_workitem('a' => 0, 'b' => -1),
      new_workitem('a' => 1)
    ]
  end

  def test_override

    assert_equal(
      { 'fields' => { 'a' => 1 } },
      Merger.new.merge_workitems(new_workitems, 'override', true))
    assert_equal(
      { 'fields' => { 'a' => 0, 'b' => -1 } },
      Merger.new.merge_workitems(new_workitems.reverse, 'override', true))
  end

  def test_mix

    assert_equal(
      { 'fields' => { 'a' => 1, 'b' => -1 } },
      Merger.new.merge_workitems(new_workitems, 'mix', true))
    assert_equal(
      { 'fields' => { 'a' => 0, 'b' => -1 } },
      Merger.new.merge_workitems(new_workitems.reverse, 'mix', true))
  end

  def test_isolate

    assert_equal(
      { 'fields' => {
        '0' => { 'a' => 0, 'b' => -1 },
        '1' => { 'a' => 1 }
      } },
      Merger.new.merge_workitems(new_workitems, 'isolate', true))
    assert_equal(
      { 'fields' => {
        '0' => { 'a' => 1 },
        '1' => { 'a' => 0, 'b' => -1 }
      } },
      Merger.new.merge_workitems(new_workitems.reverse, 'isolate', true))
  end

  def test_stack

    assert_equal(
      { 'fields' => {
          'stack' => [ { 'a' => 0, 'b' => -1 }, { 'a' => 1 } ],
          'stack_attributes' => nil
      } },
      Merger.new.merge_workitems(new_workitems, 'stack', true))
    assert_equal(
      { 'fields' => {
          'stack' => [ { 'a' => 1 }, { 'a' => 0, 'b' => -1 } ],
          'stack_attributes' => nil
      } },
      Merger.new.merge_workitems(new_workitems.reverse, 'stack', true))
  end

  def test_unknown

    assert_equal(
      { 'fields' => { 'a' => 0, 'b' => -1 } },
      Merger.new.merge_workitems(new_workitems, '???', true))
    assert_equal(
      { 'fields' => { 'a' => 1 } },
      Merger.new.merge_workitems(new_workitems.reverse, '???', true))
  end

  def test_union

    workitems = [
      new_workitem('a' => 0, 'b' => [ 'x', 'y' ], 'c' => { 'aa' => 'bb' }),
      new_workitem('a' => 1, 'b' => [ 'y', 'z' ], 'c' => { 'cc' => 'dd' })
    ]

    assert_equal(
      { 'fields' => {
        'a' => 1,
        'b' => [ 'x', 'y', 'z' ],
        'c' => { 'aa' => 'bb', 'cc' => 'dd' }
      } },
      Merger.new.merge_workitems(workitems, 'union', true))

    workitems = [
      new_workitem('a' => 0, 'b' => [ 'x', 'y' ], 'c' => { 'aa' => 'bb' }),
      new_workitem('a' => 1, 'b' => [ 'x', 'z' ], 'c' => { 'cc' => 'dd' })
    ]

    assert_equal(
      { 'fields' => {
        'a' => 1, 'b' => [ 'x', 'y', 'x', 'z' ], 'c' => { 'aa' => 'bb', 'cc' => 'dd' }
      } },
      Merger.new.merge_workitems(workitems, 'union', false))
  end

  def test_concat

    workitems = [
      new_workitem('a' => 0, 'b' => [ 'x', 'y' ], 'c' => { 'aa' => 'bb' }),
      new_workitem('a' => 1, 'b' => [ 'y', 'z' ], 'c' => { 'cc' => 'dd' })
    ]

    assert_equal(
      { 'fields' => {
        'a' => 1,
        'b' => [ 'x', 'y', 'y', 'z' ],
        'c' => { 'aa' => 'bb', 'cc' => 'dd' }
      } },
      Merger.new.merge_workitems(workitems, 'concat'))
  end
end

