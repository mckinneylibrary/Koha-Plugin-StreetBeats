CREATE TABLE IF NOT EXISTS streetbeats_slots (
    slot_id INT(11) NOT NULL AUTO_INCREMENT,
    borrowernumber INT(11) NOT NULL,
    location_id INT(11) NOT NULL,
    start_time DATETIME NOT NULL,
    PRIMARY KEY (slot_id),
    CONSTRAINT fk_sb_patron FOREIGN KEY (borrowernumber) REFERENCES borrowers (borrowernumber)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
