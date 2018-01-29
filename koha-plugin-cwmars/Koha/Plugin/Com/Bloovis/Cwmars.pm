package Koha::Plugin::Com::Bloovis::Cwmars;

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
use MARC::Record;
use MARC::Batch;
use Cwd qw(abs_path);
use URI::Escape qw(uri_unescape);
use LWP::UserAgent;
use File::Temp;

## Here we set our plugin version
our $VERSION = "1.0";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'C/W MARS Plugin',
    author          => 'Mark Alexander',
    date_authored   => '2018-01-28',
    date_updated    => '2018-01-28',
    minimum_version => '16.06.00.018',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin implements a MARC import format converter '
      . 'for C/W MARS web pages that contain MARC information.',
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

## The existence of a 'to_marc' subroutine means the plugin is capable
## of converting some type of file to MARC for use from the stage records
## for import tool
##
## This example takes a text file, each line of which contains a URL
## pointing to a C/W Mars web page containing MARC information for
## a holding, and converts each web page to the equivelent MARC record.

sub cwmars {
     my ( $tempfile, $tfh );
     my $url = shift;

     ( $tfh, $tempfile ) = File::Temp::tempfile( SUFFIX => '.marc', UNLINK => 1 );
     system('/usr/local/bin/cwmars.rb', '-o', $url, $tempfile);

     my $batch = MARC::Batch->new('USMARC', $tempfile);
     close $tfh;
     $batch->strict_off();

     my $marc = $batch->next;
     return $marc;
}

sub to_marc {
    my ( $self, $args ) = @_;

    my $data = $args->{data};

    my $batch = q{};

    foreach my $line ( split( /\n/, $data ) ) {
        chomp($line);
	$line =~ s/\r//;	# Get rid of Windows newline cruft
        my $record = cwmars($line);
        $batch .= $record->as_usmarc() . "\x1D";
    }

    return $batch;
}

## If your plugin can process payments online,
## and that feature of the plugin is enabled,
## this method will return true
sub opac_online_payment {
    my ( $self, $args ) = @_;

    return 0;
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
