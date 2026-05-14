package Koha::Plugin::Com::BWS::StreetBeats;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use Koha::Patrons;
use JSON;

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = {
        class           => 'Koha::Plugin::Com::BWS::StreetBeats',
        name            => 'StreetBeats Integration',
        author          => 'McKinney Public Library System',
        description     => 'Musician booking and analytics. (ByWater Optimized Version)',
        date_authored   => '2026-05-14',
        date_updated    => '2026-05-14',
        minimum_version => '20.05',
        version         => '1.8.0',
    };
    return $class->SUPER::new($args);
}

# -------------------------------------------------------------------------
# STAFF DASHBOARD
# -------------------------------------------------------------------------
sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $dbh = C4::Context->dbh;

    my $userenv = C4::Context->userenv;
    unless ( ($userenv && ($userenv->{flags} & 1)) || $self->can_be_managed ) {
        print $cgi->redirect("/cgi-bin/koha/mainpage.pl");
        exit;
    }

    my $stats = {};
    $stats->{total_active}     = $dbh->selectrow_array("SELECT COUNT(*) FROM streetbeats_slots WHERE start_time >= NOW()");
    $stats->{unique_musicians} = $dbh->selectrow_array("SELECT COUNT(DISTINCT borrowernumber) FROM streetbeats_slots");
    $stats->{top_location}     = $dbh->selectrow_array("SELECT l.location_name FROM streetbeats_slots s JOIN streetbeats_locations l ON s.location_id = l.location_id GROUP BY s.location_id ORDER BY COUNT(*) DESC LIMIT 1") || "None";
    $stats->{avg_per_week}     = $dbh->selectrow_array("SELECT COUNT(*) FROM streetbeats_slots WHERE start_time >= DATE_SUB(NOW(), INTERVAL 7 DAY)");

    my $query = "
        SELECT s.*, l.location_name, b.cardnumber, b.firstname, b.surname, b.borrowernumber,
               (SELECT COUNT(*) FROM streetbeats_profiles p WHERE p.borrowernumber = b.borrowernumber) as has_profile
        FROM streetbeats_slots s
        JOIN streetbeats_locations l ON s.location_id = l.location_id
        JOIN borrowers b ON s.borrowernumber = b.borrowernumber
        ORDER BY s.start_time DESC
    ";
    my $slots = $dbh->selectall_arrayref($query, { Slice => {} });

    # Based on Collection Intelligence structure, we call the file name only
    my $template = $self->get_template({ file => 'report.tt' });
    $template->param( slots => $slots, stats => $stats );
    print $cgi->header( -charset => 'utf-8' );
    print $template->output();
}

# -------------------------------------------------------------------------
# PATRON PORTAL (OPAC)
# -------------------------------------------------------------------------
sub opac {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $dbh = C4::Context->dbh;
    my $template = $self->get_template({ file => 'opac-booking.tt' });
    my $userenv = C4::Context->userenv;
    my $borrowernumber = $userenv ? $userenv->{number} : undef;

    if ($borrowernumber) {
        if ($cgi->param('action') eq 'update_profile') {
            $dbh->do("INSERT INTO streetbeats_profiles (borrowernumber, bio, tip_link, social_link, image_url) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE bio = ?, tip_link = ?, social_link = ?, image_url = ?", undef, $borrowernumber, $cgi->param('bio'), $cgi->param('tip_link'), $cgi->param('social_link'), $cgi->param('image_url'), $cgi->param('bio'), $cgi->param('tip_link'), $cgi->param('social_link'), $cgi->param('image_url'));
        }
        if ($cgi->param('action') eq 'book') {
            my $time = $cgi->param('start_time'); $time =~ s/T/ /; $time .= ":00";
            if ( $self->is_slot_available($cgi->param('location_id'), $time) && $self->can_patron_perform($borrowernumber) ) {
                $dbh->do("INSERT INTO streetbeats_slots (borrowernumber, location_id, start_time) VALUES (?, ?, ?)", undef, $borrowernumber, $cgi->param('location_id'), $time);
                $template->param( status => 'success' );
            }
        }
    }

    $template->param(
        profile   => $dbh->selectrow_hashref("SELECT * FROM streetbeats_profiles WHERE borrowernumber = ?", undef, $borrowernumber),
        locations => $dbh->selectall_arrayref("SELECT * FROM streetbeats_locations", { Slice => {} }),
        my_slots  => $dbh->selectall_arrayref("SELECT s.start_time, l.location_name FROM streetbeats_slots s JOIN streetbeats_locations l ON s.location_id = l.location_id WHERE s.borrowernumber = ?", { Slice => {} }, $borrowernumber),
        logged_in_user => $borrowernumber,
    );
    print $cgi->header( -charset => 'utf-8' ); 
    print $template->output();
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    if ($cgi->param('loc_name')) {
        C4::Context->dbh->do("INSERT INTO streetbeats_locations (location_name, description) VALUES (?, ?)", undef, $cgi->param('loc_name'), $cgi->param('loc_desc'));
    }
    my $template = $self->get_template({ file => 'configure.tt' });
    print $cgi->header( -charset => 'utf-8' );
    print $template->output();
}

sub is_slot_available {
    my ( $self, $location_id, $start_time ) = @_;
    my $count = C4::Context->dbh->selectrow_array("SELECT COUNT(*) FROM streetbeats_slots WHERE location_id = ? AND start_time = ?", undef, $location_id, $start_time);
    return $count == 0;
}

sub can_patron_perform {
    my ($self, $borrowernumber) = @_;
    my $patron = Koha::Patrons->find($borrowernumber);
    return ($patron && !$patron->restricted) ? 1 : 0;
}

sub install {
    my ( $self, $args ) = @_;
    my $dbh = C4::Context->dbh;
    $dbh->do(q{CREATE TABLE IF NOT EXISTS streetbeats_locations (location_id INT(11) NOT NULL AUTO_INCREMENT, location_name VARCHAR(255) NOT NULL, description TEXT, PRIMARY KEY (location_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;});
    $dbh->do(q{CREATE TABLE IF NOT EXISTS streetbeats_profiles (borrowernumber INT(11) NOT NULL, bio TEXT, tip_link VARCHAR(255), social_link VARCHAR(255), image_url VARCHAR(255), PRIMARY KEY (borrowernumber), CONSTRAINT fk_sb_profile_patron FOREIGN KEY (borrowernumber) REFERENCES borrowers (borrowernumber) ON DELETE CASCADE) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;});
    $dbh->do(q{CREATE TABLE IF NOT EXISTS streetbeats_slots (slot_id INT(11) NOT NULL AUTO_INCREMENT, borrowernumber INT(11) NOT NULL, location_id INT(11) NOT NULL, start_time DATETIME NOT NULL, PRIMARY KEY (slot_id), CONSTRAINT fk_sb_patron FOREIGN KEY (borrowernumber) REFERENCES borrowers (borrowernumber) ON DELETE CASCADE, CONSTRAINT fk_sb_location FOREIGN KEY (location_id) REFERENCES streetbeats_locations (location_id) ON DELETE CASCADE) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;});
    $dbh->do(q{INSERT IGNORE INTO permissions (module_bit, code, description) VALUES (19, 'manage_streetbeats', 'Access to manage StreetBeats musician bookings')});
    return 1;
}

sub uninstall {
    my ( $self, $args ) = @_;
    C4::Context->dbh->do("DELETE FROM permissions WHERE code = 'manage_streetbeats'");
    return 1;
}

1;
