package Koha::Plugin::Com::McKinney::StreetBeats;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = {
        name            => 'StreetBeats Integration',
        author          => 'McKinney Public Library',
        description     => 'Centralized musician booking via library cards.',
        date_authored   => '2026-05-13',
        date_updated    => '2026-05-13',
        minimum_version => '22.11',
        version         => '1.0',
    };
    return $class->SUPER::new($args);
}

sub install {
    my ( $self, $args ) = @_;
    my $db = C4::Context->dbh;
    # Execute your MariaDB table creation logic here
    return 1;
}

sub tool {
    my ( $self, $args ) = @_;
    my $template = $self->get_template({ file => 'streetbeats/report.tt' });
    print $template->output();
}
