(function ($) {
    "use strict";

    // Instance the tour.
    $(window).on("load", function () {
        window.tour = new Tour({
            steps: [
                {
                    element: "#ruleset",
                    title: "Title of my ruleset",
                    content: "Content of my ruleset",
                    backdrop: true,
                    autoscroll: true,
                    smartPlacement: true,
                    keyboard: true
                },
                {
                    element: "#ddl",
                    title: "Title of my ddl",
                    content: "Content of my ddl",
                    backdrop: true,
                    autoscroll: true,
                    smartPlacement: true,
                    keyboard: true
                },
                {
                    element: "#output",
                    title: "Title of output button",
                    content: "Content of output button",
                    backdrop: true,
                    autoscroll: true,
                    smartPlacement: true,
                    keyboard: true
                },
                {
                    element: "#ctrl-button",
                    title: "Title of build button",
                    content: "Content of build button",
                    backdrop: true,
                    autoscroll: true,
                    smartPlacement: true,
                    keyboard: true
                },
                {
                    element: "#sandboxEditor",
                    title: "This is the editor for your ruleset/ddl files",
                    content: "Here you can edit your code",
                    backdrop: true,
                    autoscroll: true,
                    smartPlacement: true,
                    keyboard: true
                },
                {
                    element: "#sign-up-button",
                    title: "Title of my sign up button",
                    content: "Content of my sign up button",
                    backdrop: true,
                    autoscroll: true,
                    smartPlacement: true,
                    keyboard: true
                }
            ]
        });

        // Initialize the tour.
        window.tour.init();

        // Start the tour.
        window.tour.start();

    });

})(jQuery);