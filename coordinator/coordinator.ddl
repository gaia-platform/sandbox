---------------------------------------------
-- Copyright (c) Gaia Platform LLC
-- All rights reserved.
---------------------------------------------

create table if not exists gaia_client (
      id string,
      is_active bool,
      activity_timestamp uint64
);

create table if not exists project (
      name string,
      ddl string,
      ruleset string,
      output string,
      references gaia_client
);

create table if not exists session (
      id string,
      references gaia_client,
      current references project
);
