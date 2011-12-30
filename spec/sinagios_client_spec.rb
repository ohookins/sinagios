require 'sinagios_client'
require 'rspec'
require 'spec_helper'
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

    it 'catches poorly formed URIs' do
      expect { SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'foo bar baz']) }.to raise_error(SystemExit)
      $stderr.string.should =~ /bad URI/
    end

  end

  describe '#check_valid_options' do
    it 'prints the list of required options when insufficient options are given' do
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/'])
      expect { sc.send(:check_valid_options, [:foo, :bar]) }.to raise_error(SystemExit)
      $stderr.string.should =~ /Minimum required arguments.*--foo.*--bar/
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

  describe '#parse_config_file' do
    it 'sets options based on the config file if it exists' do
      fakeconfig = File.join(File.dirname(__FILE__), 'test_data/fakeconfig.conf')
      SinagiosClient.any_instance.expects(:config_file_path).twice.returns(fakeconfig)
      expect do
        sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1'])
        sc.instance_eval do
          @uri.to_s == 'http://example.com/api/'
          @options[:author].should == 'testdude'
          @options[:password].should == 'p455w0rd'
          @options[:warnings].should == false
        end
      end.to_not raise_error
    end
  end

  describe '#schedule' do
    pending
  end

  describe '#delete' do
    pending
  end

  describe '#check_auth_creds' do
    pending
  end

  describe '#set_request_auth' do
    it 'sets the basic authentication header if authentication is required' do
      # Create the object and enable authentication by force
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/', '--author', 'testdude', '--password', 'testpass'])
      sc.instance_eval do
	@options[:use_auth] = true
      end

      # Set up a somewhat realistic request to test with auth
      req = Net::HTTP::Get.new('foo')
      sc.send(:set_request_auth, req)

      # Verify the request has the authentication header
      req['authorization'].should == 'Basic dGVzdGR1ZGU6dGVzdHBhc3M='
    end

    it 'does nothing if authentication is not required' do
      # Create the object
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/', '--author', 'testdude', '--password', 'testpass'])

      # Set up a somewhat realistic request to test
      req = Net::HTTP::Get.new('foo')
      sc.send(:set_request_auth, req)

      # Verify the request has no authentication header
      req.key?('authorization').should == false
    end
  end

  describe '#post_request' do
    it 'correctly generates a post request' do
      sc = SinagiosClient.new(['--operation', 'schedule', '--hosts', 'host1', '--uri', 'http://api.example.com/', '--author', 'testdude', '--comment', 'comment', '--duration', '300'])

      # Mock out the various objects
      req = mock('Net::HTTP::Post')
      http = mock('Net::HTTP')
      formdata = mock()
      req.expects(:set_form_data).with(formdata)
      http.expects(:request).with(req).returns('success')
      sc.instance_eval do
	@http = http
      end
      Net::HTTP::Post.expects(:new).with('/downtime/host1').returns(req)

      sc.send(:post_request, 'host1', formdata).should == 'success'
    end
  end

  describe '#delete_request' do
    it 'correctly generates a delete request' do
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/'])

      # Mock out the various objects
      req = mock('Net::HTTP::Delete')
      http = mock('Net::HTTP')
      http.expects(:request).with(req).returns('success')
      sc.instance_eval do
	@http = http
      end
      Net::HTTP::Delete.expects(:new).with('/downtime/host1').returns(req)

      sc.send(:delete_request, 'host1').should == 'success'
    end
  end

  describe '#request_path' do
    it 'assembles the correct request path for a given hostname' do
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/'])
      sc.send(:request_path, 'host1').should == '/downtime/host1'
    end
  end

  describe '#set_up_connection' do
    it 'sets the transport mode to SSL when the URI scheme is https' do
      url = 'https://api.example.com/'
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', url])

      # stub out the Net::HTTP library with pre-canned URI/connection details
      uri = URI.parse(url)
      http = mock('Net::HTTP')
      http.expects(:use_ssl=).with(true)
      Net::HTTP.expects(:new).with(uri.host, uri.port).returns(http)

      sc.send(:set_up_connection)
    end

    it 'disables SSL warnings when set in the options' do
      url = 'https://api.example.com/'
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', url, '--no-warnings'])

      # stub out the Net::HTTP and OpenSSL library calls.
      uri = URI.parse(url)
      http = mock('Net::HTTP')
      http.expects(:use_ssl=).with(true)
      openssl = mock('OpenSSL::SSL:SSLContext')
      openssl.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
      OpenSSL::SSL::SSLContext.expects(:new).returns(openssl)
      Net::HTTP.expects(:new).with(uri.host, uri.port).returns(http)

      sc.send(:set_up_connection)
    end

    it 'leaves the transport mode as plaintext when the URI scheme is http' do
      url = 'http://api.example.com/'
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', url])

      # stub out the Net::HTTP library with pre-canned URI/connection details
      uri = URI.parse(url)
      http = mock('Net::HTTP')
      Net::HTTP.expects(:new).with(uri.host, uri.port).returns(http)

      sc.send(:set_up_connection)
    end
  end

  describe '#finish_connection' do
    it 'closes the http connection if it is open' do
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/'])

      # mock out the connection
      http = mock('Net::HTTP')
      http.expects(:started?).returns(true)
      http.expects(:finish)

      # inject the mock
      sc.instance_eval do
	@http = http
      end

      sc.send(:finish_connection)
    end

    it 'does nothing if the http connection is not open' do
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/'])

      # mock out the connection
      http = mock('Net::HTTP')
      http.expects(:started?).returns(false)

      # inject the mock
      sc.instance_eval do
	@http = http
      end

      sc.send(:finish_connection)
    end
  end
end
