class sinagios (
  $cmd_file = '/var/spool/nagios/cmd/nagios.cmd',
  $status_file = '/var/log/nagios/status.dat'
) {
  $rubygems = ['rubygem-rack', 'rubygem-thin', 'rubygem-sinatra', 'rubygem-json']

  Package {
      require => Package['ruby'],
      ensure  => installed,
  }
  package {
    'ruby':
      require => undef;

    $rubygems: ;

    'sinagios':
      require => [Package['ruby'],Package[$rubygems]];
  }

  file { '/etc/sinagios/sinagios.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => 0444,
    content => template('sinagios/etc/sinagios/sinagios.conf.erb'),
    require => Package['sinagios'],
    notify  => Service['sinagios'];
  }

  service { 'sinagios':
    ensure => running,
    enable => true,
    hasstatus => true,
    subscribe => Package['sinagios'];
  }
}
