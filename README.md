🎵 StreetBeats: Centralized Municipal Booking for Koha ILS
StreetBeats is a native Koha plugin designed for the McKinney Public Library System. It transforms the library's ILS into a centralized municipal utility, allowing local musicians to book performance slots using their existing library credentials.

🚀 Overview
By migrating from a standalone architecture to a native Koha module, StreetBeats leverages existing database infrastructure and authentication layers to reduce friction for both staff and the public.

Seamless Identity: Musicians log in with their Library Card Number.

Data Ownership: Full control over booking data within the library's MariaDB instance.

Operational Efficiency: Integrated staff dashboard for monitoring and venue management.

🛠 Tech Stack
Backend: Perl (Koha Plugin Framework)

Database: MariaDB (Native Koha tables)

Frontend: Template Toolkit (TT2) & Bootstrap

Integration: Supports JSON-based API calls for hybrid Next.js frontends.

📦 Installation & Deployment
Since this project is managed via GitHub, follow these steps to package and install the plugin:

Download Source: Download this repository as a .zip file.

Prepare Package: Rename the extension from .zip to .kpz.

Ensure the Koha and streetbeats folders are at the root level of the archive.

Upload to Koha:

Go to Koha Administration > Plugins > Upload Plugin.

Select your .kpz file and click Install.

Configure: Navigate to the plugin configuration to define your performance venues.

📋 Operational Workflows
🏛 Staff (Administration)
Permissions: Grant the manage_streetbeats flag to authorized staff members.

Venue Creation: Use the Configure menu to add performance locations (e.g., "Memorial Fountain").

Monitoring: Use the Run Tool dashboard to audit upcoming bookings and verify patron standings.

🎸 Public (Musicians)
Authentication: Musicians log into the OPAC using their Library Card and PIN.

Booking: Select an available stage and time slot via the public StreetBeats portal.

Verification: Bookings are instantly validated against slot availability and account standing.

📂 Project Structure
Plaintext
Koha-Plugin-StreetBeats/
├── Koha/
│   └── Plugin/
│       └── Com/
│           └── McKinney/
│               └── StreetBeats.pm       # Main Logic & API Endpoints
├── streetbeats/
│   ├── configure.tt                     # Staff Configuration UI
│   ├── report.tt                        # Staff Dashboard UI
│   └── opac-booking.tt                  # Public Booking UI
└── README.md                            # You are here
🛡 License
This project is licensed under the same terms as Koha itself (GPL-3.0 or later).

🏙 Municipal Utility
Developed for the McKinney Public Library System to drive innovation and process automation in municipal government.
