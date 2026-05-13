This updated README.md reflects the evolution of StreetBeats from a logistics tool into a comprehensive artist platform. It is designed to be visually engaging and clearly communicate the project's value to both technical contributors and municipal stakeholders.

🎵 StreetBeats: The Municipal Artist Platform for Koha ILS
StreetBeats is an advanced Koha plugin that transforms the library’s Integrated Library System into a centralized municipal utility for local talent. By leveraging the library’s native MariaDB architecture, StreetBeats provides musicians with a "digital stage" to book gigs, manage their professional profiles, and accept digital tips from the community.  

✨ Key Features
🎸 For Musicians (The Artist Portal)
Seamless Identity: Instant access using existing Library Card credentials.  

Digital Stage Presence: Curate a public profile with an artist bio, social media links, and a band logo/headshot.  

Monetization: Integrated digital tip jar support (Venmo, CashApp, PayPal).  

Self-Service Booking: Real-time visibility into available performance slots across the city.  

🏟 For the Community (Public Discovery)
"What’s Playing Now": A public-facing schedule featuring artist profiles and live performance locations.  

Support Local Talent: Direct links to musician tip jars and social portfolios from the discovery page.  

🏛 For Staff (Administrative Excellence)
Analytics Dashboard: A "Quick Look" ribbon providing instant stats on active gigs, unique artists, and venue popularity.  

Venue Management: Dynamic configuration of physical stages and performance constraints.  

Data Integrity: Automated cleanup—if a patron account is deleted, associated gigs are purged to maintain database hygiene.  

🛠 Technical Architecture
StreetBeats is built with a focus on Data Ownership and Process Automation.  

Database: Extends the Koha MariaDB instance with three custom tables (locations, profiles, slots) natively linked to core library records via borrowernumber.  

Backend: Perl (Koha Plugin Framework) utilizing Koha::Patrons for secure authentication.  

Frontend: Template Toolkit (TT2) for a native "McKinney" aesthetic within the Staff and OPAC interfaces.  

📦 Installation
Package: Download this repository as a ZIP and rename the extension to .kpz.

Upload: In Koha, navigate to Administration > Plugins > Upload Plugin.

Permissions: Grant the manage_streetbeats flag to authorized staff accounts.  

📂 Project Structure
Plaintext
Koha-Plugin-StreetBeats/
├── Koha/
│   └── Plugin/
│       └── Com/
│           └── McKinney/
│               └── StreetBeats.pm       # Main Logic, Analytics & API
├── streetbeats/
│   ├── configure.tt                     # Venue Configuration UI
│   ├── report.tt                        # Staff Analytics Dashboard
│   ├── opac-booking.tt                  # Artist Profile & Booking UI
│   └── public-schedule.tt               # Community Discovery Page
└── README.md                            # You are here
🚀 Municipal Impact
Developed to align with Professional Excellence in public service, StreetBeats serves as a model for how open-source library software can drive broader community innovation and economic support for the arts.  

🛡 License
This project is licensed under the same terms as Koha itself (GPL-3.0 or later).
