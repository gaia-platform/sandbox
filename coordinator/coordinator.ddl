---------------------------------------------
-- Copyright (c) Gaia Platform LLC
-- All rights reserved.
---------------------------------------------

create table if not exists session (
      id string,
      agent_id string,
      current_project_id string,
      is_active bool,
      is_launching bool,
      keep_alive_received bool,
      last_active_timestamp uint64,
      created_timestamp uint64
);

create table if not exists project (
      id string,
      name string,
      ddl string,
      ruleset string,
      output string,
      references session
);
