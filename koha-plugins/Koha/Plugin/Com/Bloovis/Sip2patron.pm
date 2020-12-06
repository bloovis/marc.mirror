# This plugin provides an additional patron validation function
# for use by a patched version of Koha's SIP2 server.
# Find the patch SIP-plugin.patch in the root directory of
# this git repository, or obtain a copy here:
#   https://gitlab.com/bloovis/marc/blob/master/SIP-plugin.patch
# Apply this patch by doing this:
#   cd /usr/share/koha/lib
#   patch -p0 </PATH/TO/SIP-plugin.patch
# Then restart the koha SIP server:
#   koha-stop-sip <instance>
#   koha-start-sip <instance>

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
    date_updated    => '2020-12-01',
    minimum_version => '19.1100000',
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
## Return the patron if it is valid, or undef otherwise.

sub sip2_validate_patron {
    my ( $self, $args ) = @_;

    my $patron = $args->{patron};
    my $server = $args->{server};

    if ( $patron ) {
	my $id = $server->{account}->{id};
	my $attr = undef;

        #system("echo sip2_validate_patron: id is $id >>/tmp/junk");
	if ( $id eq 'kanopy' ) {
            #system("echo sip2_validate_patron: setting attr to KANOPY_OK >>/tmp/junk");
	    $attr = 'KANOPY_OK';
	} elsif ( $id eq 'gmlc' ) {
            #system("echo sip2_validate_patron: setting attr to GMLC_OK >>/tmp/junk");
	    $attr = 'GMLC_OK';
	} else {
            #system("echo sip2_validate_patron: attr is undef >>/tmp/junk");
	}
	if ($attr) {
	    #system("echo sip2_validate_patron: attr is $attr >>/tmp/junk");
	    my $borrowernumber = $patron->{borrowernumber};
	    my $realpatron = Koha::Patrons->find( $borrowernumber );
	    unless ($realpatron) {
		#system("echo 'sip2_validate_patron: no such patron $borrowernumber' >>/tmp/junk");
		return undef;
	    }
	    #system("echo 'sip2_validate_patron: calling get_extended_attribute with $borrowernumber' >>/tmp/junk");
	    my $value = $realpatron->get_extended_attribute( $attr );
	    if ($value) {
	        my $ok = $value->attribute;
		#system("echo 'sip2_validate_patron: borrowernumber is $borrowernumber, ok is $ok' >>/tmp/junk");
		return ($ok eq "1") ? $patron : undef;
	    } else {
	        #system("echo 'sip2_validate_patron: no such attribute $attr' >>/tmp/junk");
	        return undef;
	    }
	} else {
	    #system("echo sip2_validate_patron: attr is nil >>/tmp/junk");
	}
    } else {
	#system("echo sip2_validate_patron: patron is nil >>/tmp/junk");
    }

    return $patron;
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
