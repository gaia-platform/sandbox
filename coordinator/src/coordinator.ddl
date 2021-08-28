---------------------------------------------
-- Copyright (c) Gaia Platform LLC
-- All rights reserved.
---------------------------------------------

create database if not exists coordinator;

use coordinator;

create table if not exists project (
    name string,
    ddl_file string,
    ruleset_file string,
    output string
);

create table if not exists session (
    session_id string,
    agent_id string,
    is_active bool,
    last_session_timestamp uint64,
    last_agent_timestamp uint64,
    created_timestamp uint64
);

create table if not exists activity (
    type uint8,
    action uint8,
    payload string,
    timestamp uint64
);

create relationship if not exists session_projects (
    session.projects -> project[],
    project.session -> session
);

create relationship if not exists session_current_project (
    session.current_project -> project,
    project.active_session -> session
);

create relationship if not exists activity_session (
    session.activities -> activity[],
    activity.session -> session
);
