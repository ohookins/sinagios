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

  describe '#parse_uri' do
    it 'catches poorly formed URIs' do
      expect { SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'foo bar baz']) }.to raise_error(SystemExit)
      $stderr.string.should =~ /bad URI/
    end

    it 'accepts correctly formed URIs' do
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/'])

      sc.instance_eval do
	@uri.class.should == URI::HTTP
      end
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
    before(:each) do
      # mock out the starting checks and connection setup as we need to intercept the request
      @sc = SinagiosClient.new(['--operation', 'schedule', '--hosts', 'host1', '--comment', 'test comment', '--duration', '300', '--uri', 'http://api.example.com/', '--author', 'testdude', '--password', 'testpass'])
      @sc.expects(:check_valid_options)
      @sc.expects(:set_up_connection)

      # save outputs for checking
      $stdout, $stderr = StringIO.new(), StringIO.new()
    end

    after(:each) do
      # Reset outputs to normal
      $stdout, $stderr = STDOUT, STDERR
    end

    it 'correctly schedules downtime for a single host' do
      # mock HTTP request with a 201 result
      http = mock('Net::HTTP')
      result = mock('Net::HTTP result')
      result.expects(:code).at_least_once.returns('201')
      http.expects(:request).returns(result)
      http.expects(:started?).returns(true)
      http.expects(:finish)
      @sc.instance_eval do
	@http = http
      end

      # Call schedule and check for correct output
      @sc.send(:schedule)
      $stdout.string.should =~ /Downtime scheduled for host1/
    end

    it 'correctly schedules downtime for several hosts' do
      # mock HTTP request with a 201 result
      http = mock('Net::HTTP')
      result = mock('Net::HTTP result')
      result.expects(:code).at_least_once.returns('201')
      http.expects(:request).at_least_once.returns(result)
      http.expects(:started?).returns(true)
      http.expects(:finish)

      # Set up the mock http object and add more hosts to be scheduled
      @sc.instance_eval do
	@http = http
	@options[:hosts] = ['host1', 'host2', 'host3']
      end

      # Call schedule and check for correct output
      @sc.send(:schedule)
      $stdout.string.should == "Downtime scheduled for host1\nDowntime scheduled for host2\nDowntime scheduled for host3\n"
    end

    it 'retries the request when authentication is required' do
      # mock HTTP requests
      http = mock('Net::HTTP')

      # http request results with 401 and 201 codes
      result401 = mock('Net::HTTP result 401')
      result401.expects(:code).at_least_once.returns('401')
      result201 = mock('Net::HTTP result 201')
      result201.expects(:code).at_least_once.returns('201')

      # Subsequent requests occur in order
      http.expects(:request).at_least_once.returns(result401, result201)
      http.expects(:started?).returns(true)
      http.expects(:finish)

      # Set up the mock http object and set auth details
      @sc.instance_eval do
	@http = http
	@options[:author] = 'testdude'
	@options[:password] = 'testpass'
      end

      # Call schedule and check for correct output
      @sc.send(:schedule)
      $stdout.string.should =~ /Downtime scheduled for host1/
    end

    it 'fails when authentication to the API fails' do
      # mock HTTP requests
      http = mock('Net::HTTP')

      # http request results with just authentication failed code
      result401 = mock('Net::HTTP result 401')
      result401.expects(:code).at_least_once.returns('401')

      # Subsequent requests are just repeats of the same 401
      http.expects(:request).at_least_once.returns(result401)
      http.expects(:started?).returns(true)
      http.expects(:finish)

      # Set up the mock http object and set auth details
      @sc.instance_eval do
	@http = http
	@options[:author] = 'testdude'
	@options[:password] = 'testpass'
      end

      # Call the delete and check for error output
      @sc.send(:schedule)
      $stderr.string.should =~ /401 - authentication failed/
    end
  end

  describe '#delete' do
    before(:each) do
      # mock out the starting checks and connection setup as we need to intercept the request
      @sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/'])
      @sc.expects(:check_valid_options)
      @sc.expects(:set_up_connection)

      # save outputs for checking
      $stdout, $stderr = StringIO.new(), StringIO.new()
    end

    after(:each) do
      # Reset outputs to normal
      $stdout, $stderr = STDOUT, STDERR
    end

    it 'returns successfully when downtime has been deleted' do
      # mock HTTP request with a 200 result
      http = mock('Net::HTTP')
      result = mock('Net::HTTP result')
      result.expects(:code).at_least_once.returns('200')
      http.expects(:request).returns(result)
      http.expects(:started?).returns(true)
      http.expects(:finish)
      @sc.instance_eval do
	@http = http
      end

      # Call the delete and check for correct output
      @sc.send(:delete)
      $stdout.string.should =~ /Downtime deleted for host1/
    end

    it 'makes a second request with authentication when a 401 is received' do
      # mock HTTP requests
      http = mock('Net::HTTP')

      # http request results with 401 and 200 codes
      result401 = mock('Net::HTTP result 401')
      result401.expects(:code).at_least_once.returns('401')
      result200 = mock('Net::HTTP result 200')
      result200.expects(:code).at_least_once.returns('200')

      # Subsequent requests occur in order
      http.expects(:request).at_least_once.returns(result401, result200)
      http.expects(:started?).returns(true)
      http.expects(:finish)

      # Set up the mock http object and set auth details
      @sc.instance_eval do
	@http = http
	@options[:author] = 'testdude'
	@options[:password] = 'testpass'
      end

      # Call the delete and check for correct output
      @sc.send(:delete)
      $stdout.string.should =~ /Downtime deleted for host1/
    end

    it 'fails when an authenticated request is sent to the server but fails' do
      # mock HTTP requests
      http = mock('Net::HTTP')

      # http request results with just authentication failed code
      result401 = mock('Net::HTTP result 401')
      result401.expects(:code).at_least_once.returns('401')

      # Subsequent requests occur in order
      http.expects(:request).at_least_once.returns(result401)
      http.expects(:started?).returns(true)
      http.expects(:finish)

      # Set up the mock http object and set auth details
      @sc.instance_eval do
	@http = http
	@options[:author] = 'testdude'
	@options[:password] = 'testpass'
      end

      # Call the delete and check for error output
      @sc.send(:delete)
      $stderr.string.should =~ /401 - authentication failed/
    end

    it 'fails when downtime was not found by the server' do
      # mock HTTP requests
      http = mock('Net::HTTP')

      # http request results with not found code
      result404 = mock('Net::HTTP result 404')
      result404.expects(:code).at_least_once.returns('404')

      # Subsequent requests occur in order
      http.expects(:request).at_least_once.returns(result404)
      http.expects(:started?).returns(true)
      http.expects(:finish)

      # Set up the mock http object
      @sc.instance_eval do
	@http = http
      end

      # Call the delete and check for error output
      @sc.send(:delete)
      $stderr.string.should =~ /404 - downtime for host1 was not found/
    end

    it 'makes a request to the server for each host in a list of hosts' do
      # mock HTTP requests
      http = mock('Net::HTTP')

      # http request results with success. We expect 3 calls per host (9 total).
      result200 = mock('Net::HTTP result 200')
      result200.expects(:code).times(9).returns('200')

      # Subsequent requests occur in order
      http.expects(:request).at_least_once.returns(result200)
      http.expects(:started?).returns(true)
      http.expects(:finish)

      # Set up the mock http object, and add three hosts to be processed
      @sc.instance_eval do
	@http = http
	@options[:hosts] = ['host1', 'host2', 'host3']
      end

      # Call the delete and check for error output
      @sc.send(:delete)
      $stdout.string.should == "Downtime deleted for host1\nDowntime deleted for host2\nDowntime deleted for host3\n"
    end
  end

  describe '#check_auth_creds' do
    it 'exits with an error when insufficient credentials are given' do
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/'])
      sc.expects(:finish_connection)

      expect do
        sc.send(:check_auth_creds)
      end.to raise_error(SystemExit)
      $stderr.string.should =~ /authentication was requested/
    end

    it 'passes when sufficient credentials are given' do
      sc = SinagiosClient.new(['--operation', 'delete', '--hosts', 'host1', '--uri', 'http://api.example.com/', '--author', 'testdude', '--password', 'testpass'])
      sc.send(:check_auth_creds)
    end
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
