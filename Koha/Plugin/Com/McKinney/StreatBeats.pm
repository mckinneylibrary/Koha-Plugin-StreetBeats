package Koha::Plugin::Com::McKinney::StreetBeats;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use Koha::Patrons;
use JSON;

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = {
        name            => 'StreetBeats Integration',
        author          => 'McKinney Public Library System',
        description     => 'Centralized municipal musician booking utilizing Koha patron authentication.',
        date_authored   => '2026-05-13',
        date_updated    => '2026-05-13',
        minimum_version => '22.11',
        version         => '1.3', 
    };
    return $class->SUPER::new($args);
}

# -------------------------------------------------------------------------
# OPAC INTERFACE: Public Booking Page
# -------------------------------------------------------------------------
sub opac {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $dbh = C4::Context->dbh;
    my $template = $self->get_template({ file => 'streetbeats/opac-booking.tt' });

    # Identify the logged-in patron
    my $userenv = C4::Context->userenv;
    my $borrowernumber = $userenv ? $userenv->{number} : undef;

    # Handle Form Submission
    if ($cgi->param('action') eq 'book' && $borrowernumber) {
        my $loc_id = $cgi->param('location_id');
        my $time   = $cgi->param('start_time');
        
        # Format HTML5 datetime-local (YYYY-MM-DDTHH:MM) to MariaDB (YYYY-MM-DD HH:MM:00)
        $time =~ s/T/ /;
        $time .= ":00";

        if ( $self->is_slot_available($loc_id, $time) && $self->can_patron_perform($borrowernumber) ) {
            my $insert = "INSERT INTO streetbeats_slots (borrowernumber, location_id, start_time) VALUES (?, ?, ?)";
            $dbh->do($insert, undef, $borrowernumber, $loc_id, $time);
            $template->param( status => 'success' );
        } else {
            $template->param( status => 'error', message => 'Slot unavailable or account restricted.' );
        }
    }

    # Fetch Data for Display
    my $locations = $dbh->selectall_arrayref("SELECT * FROM streetbeats_locations", { Slice => {} });
    
    my $my_slots = [];
    if ($borrowernumber) {
        $my_slots = $dbh->selectall_arrayref("
            SELECT s.start_time, l.location_name 
            FROM streetbeats_slots s 
            JOIN streetbeats_locations l ON s.location_id = l.location_id 
            WHERE s.borrowernumber = ? 
            ORDER BY s.start_time ASC", 
        { Slice => {} }, $borrowernumber);
    }

    $template->param(
        locations      => $locations,
        my_slots       => $my_slots,
        logged_in_user => $borrowernumber,
    );

    print $cgi->header( -charset => 'utf-8' );
    print $template->output();
}

# -------------------------------------------------------------------------
# STAFF INTERFACE: The Dashboard
# -------------------------------------------------------------------------
sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    
    my $userenv = C4::Context->userenv;
    my $is_super = ($userenv && ($userenv->{flags} & 1));
    unless ( $is_super || $self->can_user_manage ) {
        print $cgi->redirect("/cgi-bin/koha/mainpage.pl");
        exit;
    }

    my $dbh = C4::Context->dbh;
    my $query = "
        SELECT s.start_time, l.location_name, b.cardnumber, b.firstname, b.surname
        FROM streetbeats_slots s
        JOIN streetbeats_locations l ON s.location_id = l.location_id
        JOIN borrowers b ON s.borrowernumber = b.borrowernumber
        ORDER BY s.start_time DESC
    ";
    my $slots = $dbh->selectall_arrayref($query, { Slice => {} });

    my $template = $self->get_template({ file => 'streetbeats/report.tt' });
    $template->param( slots => $slots );
    print $template->output();
}

# -------------------------------------------------------------------------
# PUBLIC API: Endpoint for Hybrid Frontend
# -------------------------------------------------------------------------
sub public {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $action = $cgi->param('action') || '';
    
    print $cgi->header('-type' => 'application/json', '-charset' => 'utf-8');

    if ($action eq 'book_slot') {
        my $loc_id = $cgi->param('location_id');
        my $time   = $cgi->param('start_time');
        my $bor_no = $cgi->param('borrowernumber');

        if ( !$self->is_slot_available($loc_id, $time) || !$self->can_patron_perform($bor_no) ) {
            print encode_json({ status => 'error', message => 'Validation failed' });
            return;
        }

        my $dbh = C4::Context->dbh;
        $dbh->do("INSERT INTO streetbeats_slots (borrowernumber, location_id, start_time) VALUES (?, ?, ?)", undef, $bor_no, $loc_id, $time);
        print encode_json({ status => 'success' });
    }
}

# -------------------------------------------------------------------------
# CONFIGURATION & HELPERS
# -------------------------------------------------------------------------
sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $dbh = C4::Context->dbh;

    if ($cgi->param('loc_name')) {
        $dbh->do("INSERT INTO streetbeats_locations (location_name, description) VALUES (?, ?)", undef, $cgi->param('loc_name'), $cgi->param('loc_desc'));
    }

    my $template = $self->get_template({ file => 'streetbeats/configure.tt' });
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

# -------------------------------------------------------------------------
# LIFECYCLE
# -------------------------------------------------------------------------
sub install {
    my ( $self, $args ) = @_;
    my $dbh = C4::Context->dbh;

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS streetbeats_locations (
            location_id INT(11) NOT NULL AUTO_INCREMENT,
            location_name VARCHAR(255) NOT NULL,
            description TEXT,
            PRIMARY KEY (location_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS streetbeats_slots (
            slot_id INT(11) NOT NULL AUTO_INCREMENT,
            borrowernumber INT(11) NOT NULL,
            location_id INT(11) NOT NULL,
            start_time DATETIME NOT NULL,
            PRIMARY KEY (slot_id),
            CONSTRAINT fk_sb_patron FOREIGN KEY (borrowernumber) REFERENCES borrowers (borrowernumber) ON DELETE CASCADE,
            CONSTRAINT fk_sb_location FOREIGN KEY (location_id) REFERENCES streetbeats_locations (location_id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    });

    $dbh->do(q{INSERT IGNORE INTO permissions (module_bit, code, description) VALUES (19, 'manage_streetbeats', 'Access to manage StreetBeats musician bookings')});
    return 1;
}

sub uninstall {
    my ( $self, $args ) = @_;
    C4::Context->dbh->do("DELETE FROM permissions WHERE code = 'manage_streetbeats'");
    return 1;
}

1;
