window.tour = new Tour({
    steps: [
        {
            element: "#ddl",
            title: "Define the Data Model",
            content: "Defining the Data Model is the first step in creating a Gaia application. Gaia provides a SQL like Data Definition Language (DDL). " +
                "You can define tables, fields and relationships between tables. Gaia generates C++ code to easily create/read/update/delete the data.",
            lineNumber: 12,
            tabId: 'string',
            backdrop: true,
            autoscroll: true,
            smartPlacement: true,
            keyboard: true
        },
        {
            element: "#ruleset",
            title: "Define the Business Logic",
            content: "Create business logic using rules. Rules are defined within a ruleset using the Gaia Declarative language which is a superset of C++." +
                "The Gaia Declarative Language allows to declaratively access your data, as defined in the DDL, and react to its changes.",
            backdrop: true,
            autoscroll: true,
            smartPlacement: true,
            keyboard: true
        },
        {
            element: "#ctrl-button",
            title: "Build your application!",
            content: "Builds the project running the gaia tools to convert the DDL and Ruleset into C++ source code.",
            backdrop: true,
            autoscroll: true,
            smartPlacement: true,
            keyboard: true
        },
        {
            element: "#output",
            title: "Terminal",
            content: "See the output of your program!",
            backdrop: true,
            autoscroll: true,
            smartPlacement: true,
            keyboard: true
        }
    ]
});
