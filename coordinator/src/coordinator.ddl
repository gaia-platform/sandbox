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
    agent references agent,
    projects references project[],
    editor_file_requests references editor_file_request[],
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

table editor_file_request (
    name string,
    timestamp uint64,
    session references session
)

table editor_content (
    timestamp uint64,
    project_file references project_file,
    session references session
)
