require 'sinagios_client'
require 'rspec'
require 'stringio'

describe SinagiosClient do

  describe '#new' do
    it 'prints usage information when there are no command line arguments given' do
      $stderr = StringIO.new()
      expect { SinagiosClient.new([]) }.to raise_error(SystemExit)
      $stderr.string.should =~ /Usage:/
      $stderr = STDERR
    end

    it 'prints usage information when insufficient command line arguments are given' do
      $stderr = StringIO.new()
      expect { SinagiosClient.new(['--uri', 'http://api.example.com/']) }.to raise_error(SystemExit)
      $stderr.string.should =~ /Usage:/
      $stderr = STDERR
    end

    it 'gracefully handles incorrect command line options' do
      $stderr = StringIO.new()
      expect { SinagiosClient.new(['--url', 'http://api.example.com/']) }.to raise_error(SystemExit)
      $stderr.string.should =~ /invalid option: --url/
      $stderr = STDERR
    end

    it 'prints nothing when sufficient command line arguments are given' do
      $stderr = StringIO.new()
      expect { SinagiosClient.new(['--uri', 'http://api.example.com/', '--hosts', 'host1', '--operation', 'delete']) }.to_not raise_error(SystemExit)
      $stderr.string.should == ""
      $stderr = STDERR
    end
  end

  describe '#run' do
    it 'prints contextual usage information when an invalid operation is given' do
      $stderr = StringIO.new()
      expect do
        sc = SinagiosClient.new(['--operation', 'foobar'])
        sc.run()
      end.to raise_error(SystemExit)
      $stderr.string.should =~ /Operation \'foobar\' is not supported/
      $stderr = STDERR
    end
  end
end
