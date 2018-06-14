require 'test_helper'

class TestOsis2Html5 < Test::Unit::TestCase
  O = Osis2Html5

  def test_osis_id_to_inner_id
    assert_equal('1.1', O.osis_id_to_inner_id('John.1.1'))
  end
end
