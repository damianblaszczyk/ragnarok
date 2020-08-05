#!/usr/bin/perl
use warnings;
use strict;

use Carp;
use IO::Select;
use IO::Socket::INET;
use IO::Socket::SSL;
use feature 'say';

use Getopt::Long;

#
# Main subortine
#
sub Start
{
	my $configure;

	GetOptions 
	(
		"localhost=s"	=> \$configure->{LocalHost},
 		"localport=i"	=> \$configure->{LocalPort},
 		"remotehost=s"	=> \$configure->{RemoteHost},
 		"remoteport=i"	=> \$configure->{RemotePort},
 		"ssl=i" 		=> \$configure->{SSL},
 	),
	or Usage();

	if 
	(
		(not defined $configure->{LocalHost}) ||
		(not defined $configure->{LocalPort}) ||
		(not defined $configure->{RemoteHost}) ||
		(not defined $configure->{RemotePort})
	)
	{
		Usage();
	}

	BindServer( $configure );
	MainLoop( $configure );

	return 0;
}

#
# Usage subortine
#
sub Usage
{
	say "Usage: $0 --localhost=%s --localport=%d --remotehost=%s --remoteport=%d";
	say "If You need SSL connection use additional param --ssl=1";
	exit 1;
}

#
# Bind Server, Add server socket to IO::Select
# Autoflushing Server Socket
#
sub BindServer
{
	my $configure 	= shift( @_ );

	$configure->{ioselect} = IO::Select->new();

	$configure->{server} = IO::Socket::INET->new
	(
		LocalHost 	=>	$configure->{LocalHost},
		LocalPort 	=>  $configure->{LocalPort},
		Proto 		=>	'TCP',
		Listen 		=>	SOMAXCONN,
		ReuseAddr 	=>  1,
		Timeout 	=>	10,
	) or croak "Cannot create socket $!";

	$configure->{server}->autoflush( 1 );
	$configure->{ioselect}->add( $configure->{server} );

	return 0;
}

#
# Delete sockets in array IO::Select
#
sub DisconnectClient
{
	my $configure	= shift( @_ );
	my $brother		= shift( @_ );		
	my $client		= shift( @_ );
	my $server 		= shift( @_ );

	$configure->{ioselect}->remove( $client );
	$configure->{ioselect}->remove( $server );

	$client->close;
	$server->close;

	delete $brother->{$client};
	delete $brother->{$server};

	return 0;
}

#
# New client
#
sub NewClient
{
	my $configure	= shift( @_ );
	my $brother 	= shift( @_ );
	my $type 		= shift( @_ );

	my $client;
	my $target;

	eval 
	{
		if ($configure->{SSL})
		{
			$target = IO::Socket::SSL->new
			(
				$configure->{RemoteHost}.":".$configure->{RemotePort}
			);
		}
		else
		{
			$target = IO::Socket::INET->new
			(
					PeerAddr 	=> $configure->{RemoteHost},
					PeerPort 	=> $configure->{RemotePort},
					Proto 		=>	'TCP',
			);		
		}
		
		$client = $configure->{server}->accept();

		$brother->{$client} = $target;
		$brother->{$target} = $client;

		$type->{$client} = 'client';
		$type->{$target} = 'remote';

		$client->autoflush( 1 );
		$target->autoflush( 1 );

		$configure->{ioselect}->add( $client );
		$configure->{ioselect}->add( $target );
	};
	if ( $@ ) 
	{
		carp "Problem with client $!";
	}

	return 0;
}

#
# Subortine to modify RAW if You need
#
sub ModifyRaw
{
	my $socket 		= shift( @_ );
	my $type 		= shift( @_ );
	my $configure 	= shift( @_ ); 

	if ($type->{$socket} eq 'client')
	{
		# Modify data from client
		# $configure->{bufor}->{$socket}
	}
	else
	{
		# Modify data from remote
		# $configure->{bufor}->{$socket}
	}

	return 0;
}

#
# MainLoop
#
sub MainLoop 
{
	my $configure 	= shift( @_ );

	my @temp;

	my $socket;
	my $brother = {};
	my $type 	= {};

	for (;;)
	{
		foreach $socket ( $configure->{ioselect}->can_read() ) 
		{
			if ( $socket == $configure->{server} )
			{
				NewClient( $configure, $brother, $type );
			}	
			else
			{
				$socket->sysread( $configure->{bufor}->{$socket}, 8192 );
				if ( $configure->{bufor}->{$socket} )
				{
					ModifyRaw( $socket, $type, $configure );
					$brother->{$socket}->syswrite( $configure->{bufor}->{$socket}, 8192 );
				}
				else
				{
					# Problem with socket or socket closed
					# Remove socket and socket brother from array
					DisconnectClient( $configure, $brother, $socket, $brother->{$socket} );
				}
			}
		}	
	}
	return 0;
}

Start();