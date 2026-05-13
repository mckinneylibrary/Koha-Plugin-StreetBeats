package Koha::Plugin::Com::McKinney::StreetBeats;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use Koha::Patrons;

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = {
        name            => 'StreetBeats Integration',
        author          => 'McKinney Public Library System',
        description     => 'Centralized municipal musician booking utilizing Koha patron authentication.',
        date_authored   => '2026-05-13',
        date_updated    => '2026-05-13',
        minimum_version => '22.11',
        version         => '1.0',
    };
    return $class->SUPER::new($args);
}

# The tool method defines the main staff interface dashboard
sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    
    # PERMISSIONS CHECK
    my $userenv = C4::Context->userenv;
    my $is_super = ($userenv && ($userenv->{flags} & 1));
    # can_user_manage is a built-in helper that checks the 'manage_streetbeats' flag
    unless ( $is_super || $self->can_user_manage ) {
        print $cgi->redirect("/cgi-bin/koha/mainpage.pl");
        exit;
    }

    # DATA RETRIEVAL
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

    # RENDER TEMPLATE
    my $template = $self->get_template({ file => 'streetbeats/report.tt' });
    $template->param( slots => $slots );
    print $template->output();
}

# The configure method allows for plugin-specific settings
sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'streetbeats/configure.tt' });
    print $template->output();
}

# The install method runs once when the plugin is first uploaded
sub install {
    my ( $self, $args ) = @_;
    my $dbh = C4::Context->dbh;

    # 1. Create Locations Table
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS streetbeats_locations (
            location_id INT(11) NOT NULL AUTO_INCREMENT,
            location_name VARCHAR(255) NOT NULL,
            description TEXT,
            PRIMARY KEY (location_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    });

    # 2. Create Slots Table (linked to Koha Borrowers)
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

    # 3. Register Custom Permission
    # Module_bit 19 is the 'Plugins' section in Koha
    $dbh->do(q{
        INSERT IGNORE INTO permissions (module_bit, code, description) 
        VALUES (19, 'manage_streetbeats', 'Access to manage StreetBeats musician bookings')
    });

    return 1;
}

# The uninstall method cleans up when the plugin is removed
sub uninstall {
    my ( $self, $args ) = @_;
    my $dbh = C4::Context->dbh;

    # Optional: Keep data for resilience, or drop if full reset is desired.
    # $dbh->do("DROP TABLE IF EXISTS streetbeats_slots");
    # $dbh->do("DROP TABLE IF EXISTS streetbeats_locations");
    
    # Remove the custom permission
    $dbh->do("DELETE FROM permissions WHERE code = 'manage_streetbeats'");

    return 1;
}

1;
