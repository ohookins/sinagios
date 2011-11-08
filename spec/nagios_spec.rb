require 'rspec'
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
  end
end
