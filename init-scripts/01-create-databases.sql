-- uFawkesRes: Bootstrap logical databases for all downstream planes
-- This file runs ONCE on first boot. Deleting data/postgres forces a re-run.

CREATE DATABASE sonar_db;
CREATE DATABASE dojo_db;
CREATE DATABASE dora_db;
CREATE DATABASE infisical_db;
