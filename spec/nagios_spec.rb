require 'rspec'
require 'tempfile'
require 'fileutils'
require 'nagios'
require 'mocha'

describe Nagios do
  before(:each) do
    # make a temporary location for testing
    @tmpdir = Dir.mktmpdir
    FileUtils.touch(@cmd_file = File.join(@tmpdir, 'nagios.cmd'))
    FileUtils.touch(@status_file = File.join(@tmpdir, 'status.dat'))
  end

  after(:each) do
    # get rid of temp files
    FileUtils.rm_rf(@tmpdir)
  end

  describe '#new' do
    it 'raises an exception when the command file is missing' do
      FileUtils.rm(@cmd_file)
      FileUtils.rm(@status_file)
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NonExistentCmdFile)
    end

    it 'raises an exception when the command file is unwritable' do
      FileUtils.chmod(0444, @cmd_file)
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NonWritableCmdFile)
    end

    it 'raises an exception when the status file is missing' do
      FileUtils.rm(@status_file)
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NonExistentStatusFile)
    end

    it 'raises an exception when the status file is unwritable' do
      FileUtils.chmod(0444, @status_file)
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NonWritableStatusFile)
    end
  end

  describe '#get_all_downtime' do
    it 'raises no exceptions when the input file is correctly formed' do
      @status_file = File.join(File.dirname(__FILE__), 'test_data', 'status.dat.001')
      nagios = Nagios.new(@cmd_file, @status_file)

      downtime = nil
      expect { downtime = nagios.get_all_downtime }.to_not raise_error
      downtime.should eql({'example1' => {:host => [1], :service => [2]}, 'example2' => {:host => [3], :service => []}})
    end

    it 'raises exceptions when a host id is not found in the downtime block' do
      @status_file = File.join(File.dirname(__FILE__), 'test_data', 'status.dat.002')
      nagios = Nagios.new(@cmd_file, @status_file)
      expect { nagios.get_all_downtime }.to raise_error(ParseError)
    end
  end

  describe '#delete_all_downtime_for_host' do
    it 'sends the correct commands for deleting downtime' do
      @status_file = File.join(File.dirname(__FILE__), 'test_data', 'status.dat.001')
      nagios = Nagios.new(@cmd_file, @status_file)

      # Set up mocks to catch the commands that will be sent
      nagios.expects(:send_command).with('DEL_HOST_DOWNTIME;1')
      nagios.expects(:send_command).with('DEL_SVC_DOWNTIME;2')

      expect { nagios.delete_all_downtime_for_host('example1') }.to_not raise_error
    end
  end

  describe '#send_command' do
    it 'writes the given command to the command file' do
      nagios = Nagios.new(@cmd_file, @status_file)

      # Mock the call to get the current time so we have predictable output
      nagios.expects(:get_seconds_since_epoch).returns(1234567890)

      fakecommand = 'NAGIOS_DO_SOMETHING;1'
      expect { nagios.send(:send_command, fakecommand) }.to_not raise_error

      # Verify the output written to the command file
      command_output = File.open(@cmd_file, 'r').read()
      command_output.should eql("[1234567890] NAGIOS_DO_SOMETHING;1\n")
    end
  end
end
