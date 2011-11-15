class NagiosFileError < Exception; end
class ParseError < Exception; end

class Nagios
  # FIXME: Make the status and command file locations configurable
  def initialize(cmd_file = '/var/spool/nagios/cmd/nagios.cmd',
                 status_file = '/var/log/nagios/status.dat')
    @cmd_file = cmd_file
    @status_file = status_file

    unless File.exist?(@cmd_file) then raise NagiosFileError,
      "Command File #{@cmd_file} not found" end
    unless File.writable?(@cmd_file) then raise NagiosFileError,
      "Command File #{@cmd_file} not writable" end
    unless File.exist?(@status_file) then raise NagiosFileError,
      "Status File #{@status_file} not found" end
    unless File.readable?(@status_file) then raise NagiosFileError,
      "Status File #{@status_file} not readable" end
  end

  # read the status file and return the parsed downtime
  def get_all_downtime
    File.open(@status_file, 'r') do |f|
      parse_downtime(f.readlines())
    end
  end

  def delete_all_downtime_for_host(host)
    [[:host,:host],[:service,:svc]].each do |input_type,output_type|

      get_all_downtime[host][input_type].each do |id|
        send_command("DEL_#{output_type.to_s.upcase}_DOWNTIME;#{id}")
      end
    end
    return "All downtime deleted for #{host}"
  end

  # Schedule a fixed amount of host downtime starting now.
  def schedule_host_downtime(host, duration, author, comment)
    start_time = get_seconds_since_epoch()
    end_time = Integer(duration) + start_time

    # SCHEDULE_HOST_DOWNTIME;<host_name>;<start_time>;<end_time>;<fixed>;<trigger_id>;<duration>;<author>;<comment>
    send_command("SCHEDULE_HOST_DOWNTIME;#{host};#{start_time};#{end_time};1;0;0;#{author};#{comment}")
  end

  # Schedule a fixed amount of service downtime for all services starting now.
  def schedule_services_downtime(host, duration, author, comment)
    start_time = get_seconds_since_epoch()
    end_time = Integer(duration) + start_time

    # SCHEDULE_HOST_SVC_DOWNTIME;<host_name>;<start_time>;<end_time>;<fixed>;<trigger_id>;<duration>;<author>;<comment>
    send_command("SCHEDULE_HOST_SVC_DOWNTIME;#{host};#{start_time};#{end_time};1;0;0;#{author};#{comment}")
  end

  private

  def get_seconds_since_epoch
    # I generally frown on code that purely supports testing (rather than
    # function) but mocking Time#now is really asking for trouble.
    Time.now.utc.to_i
  end

  def send_command(command)
    # Send a command to the command file. Mostly a wrapper around simple I/O
    # for the sake of testability and encapsulation.
    File.open(@cmd_file, 'w') do |cmd_file|
      cmd_file.puts("[#{get_seconds_since_epoch}] #{command}")
    end
  end

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
        # Make sure we have already seen a host
        if ! (host and downtime.has_key?(host))
          raise ParseError, "Found downtime_id without a valid host_name. Line #{i+1} of status file: #{line}"
        end

        # Cast relatively safely to an int. Non-ints will raise ArgumentError.
        downtime[host][state] << Integer($~[1])

      # }
      elsif line =~ /\}/ and [:host, :service].include?(state)
        state = :outsideblock
        host = nil

      end
    end
    return downtime
  end
end
