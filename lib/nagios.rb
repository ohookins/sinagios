class NonExistentCmdFile < Exception; end
class NonWritableCmdFile < Exception; end
class NonExistentStatusFile < Exception; end
class NonWritableStatusFile < Exception; end
class ParseError < Exception; end

class Nagios
  # FIXME: Harvest the cmd_file/status_file location from actual Nagios config
  # somehow
  def initialize(cmd_file = '/var/spool/nagios/cmd/nagios.cmd',
                 status_file = '/var/log/nagios/status.dat')
    @cmd_file = cmd_file
    @status_file = status_file

    unless File.exist?(@cmd_file) then raise NonExistentCmdFile end
    unless File.writable?(@cmd_file) then raise NonWritableCmdFile end
    unless File.exist?(@status_file) then raise NonExistentStatusFile end
    unless File.writable?(@status_file) then raise NonWritableStatusFile end
  end

  # read the status file and return the parsed downtime
  def read_all_downtime
    File.open(@status_file, 'r') do |f|
      parse_downtime(f.readlines())
    end
  end

  private

  def parse_downtime(status_text)
    # Parse the status file with a vague state machine
    state = :outsideblock
    host = nil
    downtime = {}

    # Pass through the array by index so we can give some debug information
    # when we find a bad line.
    status_text.each_index do |i|
      line = status_text[i]

      ### Expected states
      # servicedowntime {
      # hostdowntime {
      if line =~ /^(service|host)downtime \{/ and state == :outsideblock
        state = $~[1].to_sym

      # host_name=foobarbaz
      elsif line =~ /host_name=(.*)/ and [:host, :service].include?(state)
        host = $~[1]
        downtime[host] ||= {:host => [], :service => []}

      # downtime_id=1234
      elsif line =~ /downtime_id=(.*)/ and [:host, :service].include?(state)
        downtime[host][state] << $~[1]

      # }
      elsif line =~ /\}/ and [:host, :service].include?(state)
        state = :outsideblock
        host = nil

      ### Unexpected states
      elsif line =~ /\}/ and state == :outsideblock or host == nil
        # unexpected end of block
        raise ParseError, "Unexpected end of block in status file line #{i+1}: #{line}"
      elsif line =~ /^(service|host)downtime \{/ and state != :outsideblock
        # unexpected beginning of block
        raise ParseError, "Unexpected beginning of block in status file line #{i+1}: #{line}"
      end
    end
    return downtime
  end

  def delete_downtimes(host, downtimes)
    [[:host,:host],[:service,:svc]].each do |input_type,output_type|

      downtimes[host][input_type].each do |id|
        command = "[#{Time.now.utc.to_i}] DEL_#{output_type.to_s.upcase}_DOWNTIME;#{id}"
        File.open(@cmd_file, 'w') do |c|
          c.puts(command)
        end
      end
    end
    return "All downtime deleted for #{host}"
  end
end
