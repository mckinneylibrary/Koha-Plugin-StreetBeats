package Koha::Plugin::Com::BWS::StreetBeats;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = {
        class           => 'Koha::Plugin::Com::BWS::StreetBeats',
        name            => 'StreetBeats Integration',
        author          => 'McKinney Public Library System',
        description     => 'Musician booking and analytics (McKinney Edition).',
        date_authored   => '2026-05-14',
        date_updated    => '2026-05-14',
        minimum_version => '20.05',
        version         => '1.8.1',
    };
    return $class->SUPER::new($args);
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $dbh = C4::Context->dbh;

    # 1. PERMISSIONS CHECK (Standard Koha way)
    my $userenv = C4::Context->userenv;
    unless ( $userenv && ($userenv->{flags} & 1 || $userenv->{permissions}->{plugins}) ) {
        print $cgi->redirect("/cgi-bin/koha/mainpage.pl");
        exit;
    }

    # 2. RUN DIAGNOSTIC (Check if tables exist)
    my $table_check = $dbh->selectrow_array("SHOW TABLES LIKE 'streetbeats_slots'");
    unless ($table_check) {
        print $cgi->header();
        print "<h1>Setup Required</h1><p>Please click 'Configure' first to initialize the database tables.</p>";
        return;
    }

    # 3. FETCH DATA
    my $stats = {};
    $stats->{total_active} = $dbh->selectrow_array("SELECT COUNT(*) FROM streetbeats_slots") || 0;
    
    my $slots = $dbh->selectall_arrayref("SELECT * FROM streetbeats_slots LIMIT 20", { Slice => {} });

    # 4. RENDER (Using tool.tt to match working plugin)
    my $template = $self->get_template({ file => 'tool.tt' });
    $template->param( slots => $slots, stats => $stats );
    print $cgi->header( -charset => 'utf-8' );
    print $template->output();
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    
    # Force run install logic to ensure tables exist
    $self->install();

    my $template = $self->get_template({ file => 'configure.tt' });
    print $cgi->header( -charset => 'utf-8' );
    print $template->output();
}

sub install {
    my ( $self, $args ) = @_;
    my $dbh = C4::Context->dbh;
    $dbh->do(q{CREATE TABLE IF NOT EXISTS streetbeats_locations (location_id INT(11) NOT NULL AUTO_INCREMENT, location_name VARCHAR(255) NOT NULL, description TEXT, PRIMARY KEY (location_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;});
    $dbh->do(q{CREATE TABLE IF NOT EXISTS streetbeats_slots (slot_id INT(11) NOT NULL AUTO_INCREMENT, borrowernumber INT(11) NOT NULL, location_id INT(11) NOT NULL, start_time DATETIME NOT NULL, PRIMARY KEY (slot_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;});
    return 1;
}

sub uninstall { return 1; }

1;
