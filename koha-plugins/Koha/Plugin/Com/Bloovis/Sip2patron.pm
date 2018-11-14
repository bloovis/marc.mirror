package Koha::Plugin::Com::Bloovis::Sip2patron;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Members;
use C4::Auth;
use Koha::DateUtils;
use Koha::Libraries;
use Koha::Patron::Categories;
use Koha::Account;
use Koha::Account::Lines;
use Cwd qw(abs_path);
use URI::Escape qw(uri_unescape);
use LWP::UserAgent;
use File::Temp;

## Here we set our plugin version
our $VERSION = "1.0";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'SIP2 Patron Validator Plugin',
    author          => 'Mark Alexander',
    date_authored   => '2018-10-16',
    date_updated    => '2018-10-16',
    minimum_version => '16.06.00.018',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin implements a SIP2 patron validator',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## The existence of a 'sip2_validate_patron' subroutine means
## the plugin is capable of validating a patron for the SIP2 server.
## Return a true value if the patron is valid; false otherwise.

my @kanopy_ips = (
  "::ffff:192.168.122.1",	# for testing only!
  "208.66.24.46",
  "104.239.197.182",
  "18.209.148.51",
  "34.232.89.121",
  "34.234.81.211",
  "34.235.227.70",
  "34.235.53.173",
  "52.203.108.44"
);

sub sip2_validate_patron {
    my ( $self, $args ) = @_;

    my $patron = $args->{patron};
    my $server = $args->{server};

    if ( $patron ) {
        my $ipaddr = $server->{server}->{client}->peerhost;
	my $id = $server->{account}->{id};
	if ($id eq 'kanopy') {
	    foreach my $kanopy ( @kanopy_ips ) {
		if ( $ipaddr =~ /^(::ffff:)?\Q$kanopy\E$/ ) {
		    my $borrowernumber = $patron->{borrowernumber};
		    my $value = C4::Members::Attributes::GetBorrowerAttributeValue( $borrowernumber, 'KANOPY_OK' );
		    return $value eq "1";
		}
	    }
	}
    }
    return 1;
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
    my ( $self, $args ) = @_;

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

    return 1;
}

1;
