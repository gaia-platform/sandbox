(function ($) {
    "use strict";

    // Instance the tour.
    $(window).on("load", function () {
        // Define tour variable for new tour.
        var tour = new Tour({
            steps: [
                {
                    element: "#ruleset",
                    title: "Title of my ruleset",
                    content: "Content of my ruleset",
                    backdrop: true,
                    autoscroll: true,
                    smartPlacement: true,
                    keyboard: true,
                    onNext: function () {

                        // Returns index of current step.
                        var current_step = tour.getCurrentStep();

                        // Returns next step obj.
                        var next_step = tour.getStep(current_step + 1)

                        console.log(
                            {
                                lineNumber: next_step.lineNumber,
                                tabId: next_step.tabId
                            }
                        )
                    }
                },
                {
                    element: "#ddl",
                    title: "Title of my ddl",
                    content: "Content of my ddl",
                    lineNumber: 12,
                    tabId: 'string',
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
                }
            ]
        });


        // Initialize the tour.
        tour.init();

        // Start the tour.
        tour.start();

    })

})(jQuery);
