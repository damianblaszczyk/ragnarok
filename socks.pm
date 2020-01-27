package socks;

use warnings;
use strict;
use POSIX;

sub socksend
{
	my $socket		= shift(@_);
	my $bufor		= shift(@_);
	my $configure	= shift(@_);
	my @temp;

	eval
	{
		if ($$socket)
		{
			@temp = split(/\s/, $bufor);	#clean bufor end space
			if ($configure->{alive}->{$$socket})
			{
				send($$socket, "".join(" ", @temp)."\r\n", 0) || die "Send : ".$!."\r\n";
			}
		}
	};
	if ($@)
	{
		print "".$@."\r\n";
		$configure->{alive}->{$$socket}	= 0;
		$configure->{modify} = 1;
	}
	else
	{
		$configure->{timeout}->{$$socket}	= time() if ($$socket);
	}
	return 0;
}

sub sockrecv
{
	my $socket		= shift(@_);
	my $bufor		= shift(@_);
	my $configure	= shift(@_);
	my $req;

	eval
	{
		if ($$socket)
		{
			if ($configure->{alive}->{$$socket})
			{
				recv($$socket, $$bufor, POSIX::BUFSIZ, 0);
			}
		}
	};
	if ($@)
	{
		print "".$@."\r\n";
		$configure->{alive}->{$$socket}	= 0;
		$configure->{modify} = 1;
	}
	return 0;
}

1;
__END__