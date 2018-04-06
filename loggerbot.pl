#!/usr/bin/perl
# Logger Bot 1.0

use strict;
use warnings;

use IO::Socket;
use IO::Select;

my $nick = "logbot";
my $username = "logbot";
my $realname = "Logger Bot";


my $networks = {
  'FreeNode' => { 'server' => 'irc.freenode.org', 'channels' => ['#debian', '#perl', '##C', '##C++', '##linux']},
};

# Structures to help manage connections 
my %net_to_fh;
my %output_buffer;

my $select = IO::Select->new();

foreach my $name (keys (%{$networks})) 
{
  irc_connect($name);
}

while (1) 
{
  # Loop through sockets that we can read from
  foreach my $fh ($select->can_read(10)) 
  {
    # Socket handle is sending us data, or disconnected.
    my $net_name = $net_to_fh{$fh};
    my $data = <$fh>;

    if (defined $data && length $data) 
    {
      parse_line($fh,$data,$net_name);
    } else 
    {
      # Clean up old connection
      $select->remove($fh);
      delete $net_to_fh{$fh};
      delete $output_buffer{$fh};

      # Reconnect
      irc_connect($net_name);
    }

  }

  # Loop through socket handles that can write
  foreach my $fh ($select->can_write(10)) 
  {
    # Do we have anything to write to this socket? If not next;
    next if (!$output_buffer{$fh});

    if (syswrite($fh,$output_buffer{$fh}) > 0) 
    {
      delete $output_buffer{$fh};
    }
  }
}

sub irc_connect($) 
{
  my $net_name = $_[0];
  my $server = $networks->{$net_name}->{'server'};

  my $socket = IO::Socket::INET->new(PeerAddr => $server,
                                     PeerPort => '6667',
                                     Proto    => 'tcp')
               or warn "Unable to connect to $server: $!";

  return if (!$socket);

  $select->add($socket);
  $net_to_fh{$socket} = $net_name;
  $networks->{$net_name}->{'sock'} = $socket;

  if (defined $networks->{$net_name}->{'password'})
  {
    SendLine($socket, "PASS " . $networks->{$net_name}->{'password'});
  }

  SendLine($socket, "NICK ".$nick);
  SendLine($socket, "USER ".$username." 0 * :".$realname);
}

sub SendLine($$)
{
  my $fh = $_[0];
  my $line = $_[1];

  $output_buffer{$fh} .= $line ."\n";

  print ">>> $line\n";
}

sub parse_line($$$) 
{
  my ($FH, $line, $net_name) = @_;

  # Strip any trailing whitespace chars (\s \n \r, etc)
  $line =~s/\s+$//;

  my ($src, $opcode, $dest, $body);
    
  if ($line =~ /^PING :?(.*)/)
  {
    SendLine($FH, "PONG ".$1);
    return; # No need to continue with this line.
  }
  elsif ($line =~ /^:(\S*) (\S*) (\S*)\s?:?(.*)?$/)
  {
    ($src, $opcode, $dest, $body) = ($1, $2, $3, $4);
  } else 
  {
    # If we hit this point, it's unlikely we can process the line. Abort!
    print "[UNKNOWN] $line\n";
    return;
  }

  # Server send us the end of MOTD, we should join channels now.
  if ($opcode eq "375") 
  {
    foreach my $channel (@{$networks->{$net_name}->{'channels'}}) 
    {
      SendLine($FH, "JOIN ".$channel);
    }
  }

  # We got a privmsg, dump it into a log
  if (lc($opcode) eq "privmsg") 
  {
    my ($nick, $ident, $host) = ($src=~/(.+)!(.+)\@(.+)/);

    # Respond to CTCP Version requests.
    if ($body=~/^\001VERSION\001/i) 
    {
      print "Sending version response to $nick\n";
      SendLine($FH, "NOTICE ".$nick." :\001VERSION LogBot 1.0 Perl Bot\001");
    }
    else 
    {
      print "[$dest] <$nick> $body\n";
    }

  }

  if (lc($opcode) eq "mode") 
  {
    if ($src=~/(.+)!(.+)\@(.+)/)
    {
      my ($nick, $ident, $host) = ($1, $2, $3);
      print $nick." changed mode on ".$dest.": ".$body."\n";
    }
    else 
    {
      print $src." changed mode on ".$dest.": ".$body."\n";
    }
  }
}
