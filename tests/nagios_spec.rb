require 'spec'
require 'tempfile'
require 'fileutils'
require 'nagios'

describe Nagios do
  before(:each) do
    # make a temporary location for testing
    @tmpdir = Dir.mktmpdir
    @cmd_file = File.join(@tmpdir, 'nagios.cmd')
    @status_file = File.join(@tmpdir, 'status.dat')
  end

  after(:each) do
    # get rid of temp files
    FileUtils.rm_rf(@tmpdir)
  end

  describe '#new' do
    it 'raises an exception when the command file is missing' do
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NonExistentCmdFile)
    end

    it 'raises an exception when the command file is unwritable' do
      FileUtils.touch(@cmd_file)
      FileUtils.chmod(0444, @cmd_file)
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NonWritableCmdFile)
    end

    it 'raises an exception when the status file is missing' do
      FileUtils.touch(@cmd_file)
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NonExistentStatusFile)
    end

    it 'raises an exception when the status file is unwritable' do
      FileUtils.touch(@cmd_file)
      FileUtils.touch(@status_file)
      FileUtils.chmod(0444, @status_file)
      expect { Nagios.new(@cmd_file, @status_file) }.to raise_error(NonWritableStatusFile)
    end
  end


end
