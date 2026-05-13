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
        version         => '1.2', 
    };
    return $class->SUPER::new($args);
}

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
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my $slots = $sth->fetchall_arrayref({});

    my $template = $self->get_template({ file => 'streetbeats/report.tt' });
    $template->param( slots => $slots );
    print $template->output();
}

sub public {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $action = $cgi->param('action') || '';
    
    print $cgi->header('-type' => 'application/json', '-charset' => 'utf-8');

    if ($action eq 'book_slot') {
        my $loc_id = $cgi->param('location_id');
        my $time   = $cgi->param('start_time');
        my $bor_no = $cgi->param('borrowernumber');

        if ( !$self->is_slot_available($loc_id, $time) ) {
            print encode_json({ status => 'error', message => 'Slot already taken' });
            return;
        }

        if ( !$self->can_patron_perform($bor_no) ) {
            print encode_json({ status => 'error', message => 'Patron account restricted' });
            return;
        }

        my $dbh = C4::Context->dbh;
        my $insert = "INSERT INTO streetbeats_slots (borrowernumber, location_id, start_time) VALUES (?, ?, ?)";
        my $sth = $dbh->prepare($insert);
        
        if ($sth->execute($bor_no, $loc_id, $time)) {
            print encode_json({ status => 'success', message => 'Booking confirmed' });
        } else {
            print encode_json({ status => 'error', message => 'Database error' });
        }
    }
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $dbh = C4::Context->dbh;

    # Logic to save a new location if the form is submitted
    if ($cgi->param('loc_name')) {
        my $name = $cgi->param('loc_name');
        my $desc = $cgi->param('loc_desc');
        $dbh->do("INSERT INTO streetbeats_locations (location_name, description) VALUES (?, ?)", undef, $name, $desc);
    }

    my $template = $self->get_template({ file => 'streetbeats/configure.tt' });
    print $template->output();
}

sub is_slot_available {
    my ( $self, $location_id, $start_time ) = @_;
    my $dbh = C4::Context->dbh;
    my $query = "SELECT COUNT(*) FROM streetbeats_slots WHERE location_id = ? AND start_time = ?";
    my $count = $dbh->selectrow_array($query, undef, $location_id, $start_time);
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

    $dbh->do(q{
        INSERT IGNORE INTO permissions (module_bit, code, description) 
        VALUES (19, 'manage_streetbeats', 'Access to manage StreetBeats musician bookings')
    });

    return 1;
}

sub uninstall {
    my ( $self, $args ) = @_;
    my $dbh = C4::Context->dbh;
    $dbh->do("DELETE FROM permissions WHERE code = 'manage_streetbeats'");
    return 1;
}

1;
