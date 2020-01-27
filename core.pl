#!/usr/bin/perl
use IO::Select;
use IO::Handle;
use warnings;
use strict;
use Socket;

use lib ".";
use socks;
use raw;

BEGIN 
{
	$| = 1;														# Autoflush for console
	open( STDERR, '>>', "errors.log" );							# Errors in file errors.log
}

sub main ()
{
	my %configure =	(
				proxyhost		=>	'localhost',				# ProxyHost default 127.0.0.1
				proxyport		=>	'5555',						# ProxyPort default 5555
				targetaddr		=>	'insomnia.pirc.pl',			# TargetHost
				targetport		=>	'6665',						# TargetPort
				range			=>	'20000000', 				# Range sockets randomness, more for huge group connections
				rand1			=>	'',							# Don't touch
				rand2			=>	'',							# Don't touch
				protocol		=>	'tcp',						# Protocol
				select			=>	'',							# Don't touch
				socktimeout		=>	'1',						# Timeout for can_read()
				lastcheck		=>	time(),						# Don't touch
				modify			=>	0,							# Don't touch
				lineserver		=>	'',
				lineclient		=>	'',
				proxyver		=>	'20200124',					# Ragnarok version
	);

	my $server;
	my $select = IO::Select->new();

	$configure{select} = \$select;
	bindserver(\$server, \%configure);
	$select->add($server);
	srand(time());

	while (1)
	{
		sleep 1;
		eval
		{
			mainloop(\%configure, $server, $select);
		};
		print $@ if $@;
	}
	close($server);
	return 0;
}

sub mainloop 
{
	my $configure 	= shift(@_);
	my $server		= shift(@_);
	my $select		= shift(@_);

	my %temp;
	my %targetserver;
	my %client;
	my @temp;
	my @list;
	my $socket;

	while (1)
	{		
		if ((time() - $configure->{lastcheck}) > 60)
		{
			checktimeout($select, $configure);
			@list = $select->handles();
			shift(@list);
			$configure->{lastcheck} = time();
		}
		if ($configure->{modify})
		{
			checkalive($select, $configure);
		}
		foreach $socket ($select->can_read($configure->{socktimeout})) 
		{
			if ($socket == $server)
			{
				# [CLIENT CONNECTION]
				$configure->{rand1} = int(rand($configure->{range}));
				accept($temp{$configure->{rand1}}, $server);

				# [TARGETSERVER CONNECTION]
				$configure->{rand2} = int(rand($configure->{range}));
				socket($temp{$configure->{rand2}}, AF_INET, SOCK_STREAM, getprotobyname($configure->{protocol}));
				connect($temp{$configure->{rand2}}, sockaddr_in($configure->{targetport}, inet_aton($configure->{targetaddr})));

				# [CREATE DATA IN HASH]
				$configure->{alive}->{$temp{$configure->{rand1}}} = 1;
				$configure->{alive}->{$temp{$configure->{rand2}}} = 1;
				$configure->{socks}->{$temp{$configure->{rand1}}} = 'client';
				$configure->{socks}->{$temp{$configure->{rand2}}} = 'server';
				$temp{$configure->{rand1}}->autoflush(1);
				$temp{$configure->{rand2}}->autoflush(1);
				$select->add($temp{$configure->{rand1}});
				$select->add($temp{$configure->{rand2}});
				$targetserver{$temp{$configure->{rand1}}} = $temp{$configure->{rand2}};
				$client{$temp{$configure->{rand2}}} = $temp{$configure->{rand1}};
			}	
			else
			{
				socks::sockrecv(\$socket, \$configure->{bufor}->{$socket}, $configure);
				if ($configure->{bufor}->{$socket} && length($configure->{bufor}->{$socket}) > 0)
				{
					if ($configure->{rest}->{$socket})
					{
						$configure->{bufor}->{$socket} = $configure->{rest}->{$socket} . $configure->{bufor}->{$socket};
					}
					if ((substr $configure->{bufor}->{$socket}, (length($configure->{bufor}->{$socket})-1)) ne "\n")
        	                        {
						@temp = split("\n", $configure->{bufor}->{$socket});
						$configure->{rest}->{$socket} = $temp[$#temp];
                	                }
                	                else
                        	        {
                                		$configure->{rest}->{$socket} = undef;
                                        }
					@temp = split("\n", $configure->{bufor}->{$socket});
					if ((substr $configure->{bufor}->{$socket}, (length($configure->{bufor}->{$socket})-1)) ne "\n")
					{
						pop(@temp);
					}
					foreach (@temp)
					{
						if ($configure->{socks}->{$socket} eq 'client')
						{
							$configure->{lineclient} = $_ . "\n";
							raw::fromclient($configure, \$targetserver{$socket}, \$socket);
						}
						elsif ($configure->{socks}->{$socket} eq 'server')
						{
							$configure->{lineserver}	= $_ . "\n";
							raw::fromonet($configure, \$client{$socket}, \$socket);	
						}						
					}
				}
				else
				{
					if ($configure->{socks}->{$socket} eq 'client')
					{				
						delete $client{$targetserver{$socket}};
						delete $targetserver{$socket};
					}

					elsif ($configure->{socks}->{$socket} eq 'server')
					{
						delete $targetserver{$client{$socket}};
						delete $client{$socket};
					}

					$configure->{alive}->{$socket} = 0;	
					$configure->{modify} = 1;			
					next;
				}
			}
		}	
	}
	return 0;
}

sub bindserver
{
	my $server			= shift(@_);
	my $configure		= shift(@_);

	$configure->{proxyport} = $ARGV[0] if ($ARGV[0]);
	socket($$server, AF_INET, SOCK_STREAM, getprotobyname($configure->{protocol})) || die "socket: ".$!."\r\n";
	setsockopt($$server, SOL_SOCKET, SO_REUSEADDR, 1);
	bind($$server, sockaddr_in($configure->{proxyport}, inet_aton($configure->{proxyhost}))) || die "bind: ".$!."\r\n";
	listen($$server, SOMAXCONN) || die "listen: ".$!."\r\n";
	$$server->autoflush(1);	
	return 0;
}

sub checkalive
{
	my $select		= shift(@_);
	my $configure	= shift(@_);
	my @temp;

	@temp = $select->handles();
	shift(@temp);
	foreach (@temp)
	{
		unless($configure->{alive}->{$_})
		{
			$select->remove($_);
			close($_);
			delete $configure->{rest}->{$_};
			delete $configure->{socks}->{$_};
			delete $configure->{conf}->{$_};
			delete $configure->{bufor}->{$_};
			delete $configure->{alive}->{$_};
			delete $configure->{timeout}->{$_};
		}
	}
	$configure->{modify} = 0;
	return 0;
}

sub checktimeout
{
	my $select		= shift(@_);
	my $configure	= shift(@_);
	my @temp;

	@temp = $select->handles();
	shift(@temp);
	foreach (@temp)
	{
		if ($configure->{timeout}->{$_})
		{
			if ((time() - $configure->{timeout}->{$_}) > 150)
			{
				$configure->{alive}->{$_} = 0;
				$configure->{modify} = 1;	
			}
		}
	}
	return 0;
}

while (1)
{
	eval
	{
		main();
	};
	print $@ if $@;	
}

END{}
