---------------------------------------------
-- Copyright (c) Gaia Platform LLC
-- All rights reserved.
---------------------------------------------

database coordinator

table session (
    id string unique,
    is_active bool,
    last_timestamp uint64,
    created_timestamp uint64,
    current_project_name string,
    terminal_input string,
    send_project_files bool,
    agent references agent,
    is_test bool,
    projects references project[],
    editor_contents references editor_content[]
)

table agent (
    id string unique,
    in_use bool,
    last_timestamp uint64,
    created_timestamp uint64,
    session references session
)

table project (
    name string,
    version string,
    session references session,
    project_files references project_file[]
)

table project_file (
    name string,
    content string,
    project references project,
    editor_contents references editor_content[]
)

table editor_content (
    timestamp uint64,
    project_file references project_file,
    session references session
)
