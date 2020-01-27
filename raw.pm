package raw;

use warnings;
use strict;
use vars;
use socks;

sub fromclient
{
	my $configure 	= shift(@_);
	my $onet		= shift(@_);
	my $client		= shift(@_);
	my @temp;

	@temp	= split(/\s/, $configure->{lineclient});

	my %action_client = (
	'EXAMPLE_CLIENTRCV'			=>	\&client_RAW,
	);

#	if (defined $action_client{$temp[0]})
#	{
#		$action_client{$temp[0]}->($configure, $onet, $client);
#	}
#	else
#	{
		socks::socksend($onet, $configure->{lineclient}, $configure);
#	}
	return 0;
}

sub fromonet
{
	my $configure	= shift(@_);
	my $client		= shift(@_);
	my $onet		= shift(@_);
	my @temp;

	@temp   = split(/\s/, $configure->{lineserver});

	my %action_onet	= (
	'EXAMPLE_TARGETRCV'		=>	\&server_ERROR,
	);

   #     if (defined $action_onet{$temp[1]})
   #     {
   #             $action_onet{$temp[1]}->($configure, $onet, $client);
   #     }
   #     else
   #     {
                socks::socksend($client, $configure->{lineserver}, $configure);
    #    }
	return 0;
}

####################################################
#RAW FROM CLIENT
####################################################

sub client_RAW
{
  	my $configure   = shift(@_);
   	my $onet        = shift(@_);
   	my $client      = shift(@_);
	my @temp;
	my $iter;

	if ($configure->{conf}->{$$client}->{rawlog})
	{
		socks::socksend($client, ":RAGNAROK.tunnel NOTICE Auth :Rawlog is empty\r\n", $configure) if (!$configure->{raw}->{$$client});
		return(0) if (!$configure->{raw}->{$$client});

		@temp = split(/\n/, $configure->{raw}->{$$client});
		socks::socksend($client, ":RAGNAROK.tunnel NOTICE Auth :---------------------------------------\r\n", $configure);
		for ($iter = 0; $iter < ($#temp+1); $iter++)
		{
			socks::socksend($client, ":RAGNAROK.tunnel NOTICE Auth :".$temp[$iter]."\r\n", $configure);
		}
		socks::socksend($client, ":RAGNAROK.tunnel NOTICE Auth :---------------------------------------\r\n", $configure);
	}
	else
	{
		socks::socksend($client, ":RAGNAROK.tunnel NOTICE Auth :Command disable. You must writte '/quote set rawlog 1'\r\n", $configure);
	}
	return 0;
}

####################################################
#RAW FROM TARGETSERVER
####################################################

sub server_ERROR
{
 	my $configure   = shift(@_);
    my $onet        = shift(@_);
    my $client      = shift(@_);
	
	socks::socksend($client, $configure->{lineserver}, $configure);
	if ($$client)
	{
		$configure->{alive}->{$$client}	= 0;
		$configure->{modify} = 1;
	}
	if ($$onet)
	{
		$configure->{alive}->{$$onet}	= 0;
		$configure->{modify} = 1;
	}
	return 0;
}

1;
__END__
