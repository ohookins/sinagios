require 'test/unit'
require 'tempfile'
require 'fileutils'
require 'nagios'

class TestNagios < Test::Unit::TestCase
  def setup
    # make a temporary location for testing
    @tmpdir = Dir.mktmpdir
    @cmd_file = File.join(@tmpdir, 'nagios.cmd')
  end

  def teardown
    # get rid of temp files
    FileUtils.rm_rf(@tmpdir)
  end

  def test_non_existent_cmd_file
    # check that a missing command file raises an exception
    assert_raise NonExistentCmdFile do
      nagios = Nagios.new(@cmd_file)
    end
  end

  def test_unwritable_cmd_file
    # check that an unwritable command file raises an exception
    FileUtils.touch(@cmd_file)
    FileUtils.chmod(0444, @cmd_file)
    assert_raise NonWritableCmdFile do
      nagios = Nagios.new(@cmd_file)
    end
  end
end
