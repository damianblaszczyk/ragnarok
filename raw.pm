package raw;

use warnings;
use strict;
use vars;
use socks;

sub fromclient
{
	my $configure 	= shift(@_);
	my $server		= shift(@_);
	my $client		= shift(@_);
	my @temp;

	@temp	= split(/\s/, $configure->{lineclient});

	my %action_client = (
#	'EXAMPLE_CLIENTRCV'			=>	\&client_RAW,
	);

	if (defined $action_client{$temp[0]})
	{		
		$action_client{$temp[0]}->($configure, $server, $client);
	}
	else
	{
		socks::socksend($server, $configure->{lineclient}, $configure);
	}
	return 0;
}

sub fromserver
{
	my $configure	= shift(@_);
	my $client		= shift(@_);
	my $server		= shift(@_);
	my @temp;

	@temp   = split(/\s/, $configure->{lineserver});

	my %action_server	= (
#	'EXAMPLE_TARGETRCV'		=>	\&server_ERROR,
	);

    if (defined $action_server{$temp[1]})
    {
		$action_server{$temp[1]}->($configure, $server, $client);
	}
	else
	{
		socks::socksend($client, $configure->{lineserver}, $configure);
    }
	return 0;
}

####################################################
# MESSAGE FROM CLIENT
####################################################

sub client_RAW
{
  	my $configure   = shift(@_);
   	my $server 		= shift(@_);
   	my $client      = shift(@_);

	return 0;
}

####################################################
# MESSAGE FROM SERVER
####################################################

sub server_RAW
{
 	my $configure   = shift(@_);
    my $server      = shift(@_);
    my $client      = shift(@_);
	
	return 0;
}

1;
__END__
