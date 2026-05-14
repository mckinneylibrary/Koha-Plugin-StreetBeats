package Koha::Plugin::Com::McKinney::StreetBeats;

use base qw(Koha::Plugins::Base);
use C4::Context;

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = {
        name            => 'StreetBeats Skeleton Test',
        author          => 'McKinney Public Library System',
        description     => 'Diagnostic version: Checking for registration.',
        date_authored   => '2026-05-14',
        date_updated    => '2026-05-14',
        minimum_version => '19.11',
        version         => '1.7.3', 
    };
    return $class->SUPER::new($args);
}

sub tool {
    my ( $self, $args ) = @_;
    print $self->{'cgi'}->header();
    print "<h1>Registration Successful</h1><p>The skeleton is live.</p>";
}

sub opac { return 1; }
sub configure { return 1; }
sub install { return 1; }
sub uninstall { return 1; }

1;
