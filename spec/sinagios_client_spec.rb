require 'sinagios_client'
require 'rspec'
require 'stringio'

describe SinagiosClient do
  # We capture stderr output to an object and read from it in the tests
  before(:each) do
    $stderr = StringIO.new()
  end
  after(:each) do
    $stderr = STDERR
  end

  describe '#new' do
    it 'prints usage information when there are no command line arguments given' do
      expect { SinagiosClient.new([]) }.to raise_error(SystemExit)
      $stderr.string.should =~ /Usage:/
    end

    it 'prints usage information when insufficient command line arguments are given' do
      expect { SinagiosClient.new(['--uri', 'http://api.example.com/']) }.to raise_error(SystemExit)
      $stderr.string.should =~ /Usage:/
    end

    it 'gracefully handles incorrect command line options' do
      expect { SinagiosClient.new(['--url', 'http://api.example.com/']) }.to raise_error(SystemExit)
      $stderr.string.should =~ /invalid option: --url/
    end

    it 'prints nothing when sufficient command line arguments are given' do
      expect { SinagiosClient.new(['--uri', 'http://api.example.com/', '--hosts', 'host1', '--operation', 'delete']) }.to_not raise_error(SystemExit)
      $stderr.string.should == ""
    end
  end

  describe '#check_valid_options' do
    it 'prints the list of required options when insufficient options are given' do
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/'])
      expect { sc.send(:check_valid_options, [:foo, :bar]) }.to raise_error(SystemExit)
      $stderr.string.should =~ /Minimum required arguments.*--foo.*--bar/
    end

    it 'catches poorly formed URIs' do
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'foo bar baz'])
      expect { sc.send(:check_valid_options, []) }.to raise_error(SystemExit)
      $stderr.string.should =~ /bad URI/
    end
  end

  describe '#run' do
    it 'prints contextual usage information when an invalid operation is given' do
      expect do
        sc = SinagiosClient.new(['--operation', 'foobar'])
        sc.run()
      end.to raise_error(SystemExit)
      $stderr.string.should =~ /Operation \'foobar\' is not supported/
    end
  end
end
