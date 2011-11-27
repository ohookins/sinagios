require 'sinagios_client'
require 'rspec'
require 'stringio'

describe 'the Sinagios client' do
  it 'prints usage information when there are no command line arguments given' do
    $stderr = StringIO.new()
    expect { SinagiosClient.new([]) }.to raise_error(SystemExit)
    $stderr.string.should =~ /Usage:/
    $stderr = STDERR
  end
end
