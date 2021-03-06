require 'rspec'
require 'spec_helper'
require 'mocha'
require 'tempfile'
require 'fileutils'
require 'nagios'

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
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NagiosFileError, /not found/)
    end

    it 'raises an exception when the command file is unwritable' do
      FileUtils.chmod(0444, @cmd_file)
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NagiosFileError, /not writable/)
    end

    it 'raises an exception when the status file is missing' do
      FileUtils.rm(@status_file)
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NagiosFileError, /not found/)
    end

    it 'raises an exception when the status file is unreadable' do
      FileUtils.chmod(0000, @status_file)
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NagiosFileError, /not readable/)
    end

    it 'uses the configuration file specified by SINAGIOS_CONFIG' do
      # Prepare a dummy config
      configfile = File.join(@tmpdir, 'sinagios.conf')
      File.open(configfile, 'w') do |f|
        config = {'cmd_file' => @cmd_file, 'status_file' => @status_file}
        f.puts(YAML::dump(config))
      end

      # Set the environment variable override and verify the configs are set correctly
      ENV['SINAGIOS_CONFIG'] = configfile
      nagios = Nagios.new()
      nagios.cmd_file.should eql(@cmd_file)
      nagios.status_file.should eql(@status_file)
    end
  end

  describe '#get_all_downtime' do
    it 'raises no exceptions when the input file is correctly formed' do
      @status_file = File.join(File.dirname(__FILE__), 'test_data', 'status.dat.001')
      nagios = Nagios.new(@cmd_file, @status_file)

      nagios.get_all_downtime.should == {'example1' => {:host => [1], :service => [2]}, 'example2' => {:host => [3], :service => []}}
    end

    it 'raises exceptions when a host id is not found in the downtime block' do
      @status_file = File.join(File.dirname(__FILE__), 'test_data', 'status.dat.002')
      nagios = Nagios.new(@cmd_file, @status_file)
      expect { nagios.get_all_downtime }.to raise_error(ParseError)
    end

    it 'operates correctly when there is no scheduled downtime' do
      nagios = Nagios.new(@cmd_file, @status_file)
      nagios.get_all_downtime.should == {}
    end
  end

  describe '#delete_all_downtime_for_host' do
    it 'sends the correct commands for deleting downtime' do
      @status_file = File.join(File.dirname(__FILE__), 'test_data', 'status.dat.001')
      nagios = Nagios.new(@cmd_file, @status_file)

      # Set up mocks to catch the commands that will be sent
      nagios.expects(:send_command).with('DEL_HOST_DOWNTIME;1')
      nagios.expects(:send_command).with('DEL_SVC_DOWNTIME;2')

      nagios.delete_all_downtime_for_host('example1')
    end
  end

  describe '#schedule_host_downtime' do
    it 'sends the correct commands for scheduling host downtime' do
      nagios = Nagios.new(@cmd_file, @status_file)

      # Mock out time and send_command
      nagios.expects(:get_seconds_since_epoch).returns(1234567890)
      nagios.expects(:send_command).with('SCHEDULE_HOST_DOWNTIME;localhost;1234567890;1234567899;1;0;0;Test Dude;Test Downtime')

      nagios.schedule_host_downtime('localhost', '9', 'Test Dude', 'Test Downtime')
    end
  end

  describe '#schedule_services_downtime' do
    it 'sends the correct commands for scheduling all services downtime' do
      nagios = Nagios.new(@cmd_file, @status_file)

      # Mock out time and send_command
      nagios.expects(:get_seconds_since_epoch).returns(1234567890)
      nagios.expects(:send_command).with('SCHEDULE_HOST_SVC_DOWNTIME;localhost;1234567890;1234567899;1;0;0;Test Dude;Test Downtime')

      nagios.schedule_services_downtime('localhost', '9', 'Test Dude', 'Test Downtime')
    end
  end

  describe '#get_seconds_since_epoch' do
    it 'returns some positive integer' do
      nagios = Nagios.new(@cmd_file, @status_file)

      nagios.send(:get_seconds_since_epoch).should > 1000000
    end
  end

  describe '#send_command' do
    it 'writes the given command to the command file' do
      nagios = Nagios.new(@cmd_file, @status_file)
      mockcommand = 'NAGIOS_DO_SOMETHING;1'
      mocktime = 1234567890

      # Mock the call to get the current time so we have predictable output
      nagios.expects(:get_seconds_since_epoch).returns(mocktime)
      nagios.send(:send_command, mockcommand)

      # Verify the output written to the command file
      command_output = File.open(@cmd_file, 'r').read()
      command_output.should eql("[#{mocktime}] #{mockcommand}\n")
    end
  end
end
