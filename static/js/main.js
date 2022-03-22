(function ($) {
    "use strict";

    $(window).on('load', function () {
        console.log('$(window).on(load ...');
        // Load Monaco Editor
        require.config({ paths: { vs: "static/lib/monaco/vs" } });

        require(['vs/editor/editor.main'], function () {
            load();
        });

        // Generate UUID and store in cookie
        let storedSandboxUuid = getCookie("sandboxUUID");
        if (!storedSandboxUuid) {
            storedSandboxUuid = window.generateUUID();
            setCookie("sandboxUUID", storedSandboxUuid);

            // Show privacy message (since the cookie is new)
            $("#privacy-modal").show();
        } else {
            initTour();
        }
        let storedAppUUID = getCookie("appUUID");
        if (!storedAppUUID) {
            storedAppUUID = "not set yet";
            setCookie("appUUID", storedAppUUID);
        }

        window.sandboxUUID = storedSandboxUuid;
        window.appUUID = storedAppUUID;

        window.publishToCoordinator("project/stop", "current");
        window.subscribeToTopic("editor/#", false);
        window.subscribeToTopic("project/#", false);
        window.subscribeToTopic("session", false);
        window.subscribeToTopic("appUUID", false);

        window.selectProject($("#scenario").attr("data-scenario"));
    });

    var cursorTimer = null;
    var cursorVisible = false;
    var outputTerminalContent = '';
    var state = null;
    var editor = null;
    var data = {
        ruleset: {
            model: null,
            state: null
        },
        ddl: {
            model: null,
            state: null
        },
        cpp: {
            model: null,
            state: null
        }
    };
    var projects = {
        frequent_flyer: ['src/frequent_flyer.cpp', 'src/frequent_flyer.ddl', 'src/frequent_flyer.ruleset', 'README.md'],
        direct_access: ['hospital.ddl', 'hospital.cpp'],
        rules: ['clinic.ddl', 'clinic.ruleset'],
        access_control: ['src/access_control.ddl', 'src/access_control.ruleset', 'get_started.md']
    };

    resetState();

    function initTour() {
        // Initialize the tour.
        window.tour.init();

        // Start the tour.
        window.tour.start();
    }

    function resetState() {
        state = {
            project: {
                current: null,
                buildStatus: 'unknown',
                runStatus: 'stopped',
                edits: new Set()
            },
            session: {
                loading: true,
                loadCountdown: 0
            }
        };
    }

    $("#outputTerminal").focus(function() {
        $("#sandboxEditor").css("height","20vh");
        $("#outputTerminalDiv").css("height","60vh");
    });

    $("#outputTerminal").blur(function() {
        $("#sandboxEditor").css("height","60vh");
        $("#outputTerminalDiv").css("height","20vh");
    });

    // Reads the file name and converts it to cpp/sql depending on extension.
    // Defaults to text.
    function fileFormat(fileExt) {
        switch (fileExt) {
            case 'ruleset': case 'cpp': return 'cpp';
            case 'ddl': return 'sql';

            default:
                break;
        }
        return 'text';
    }

    function stopCursorBlink() {
        if (cursorTimer) {
            clearInterval(cursorTimer);
            cursorTimer = null;
            $("#outputTerminal").val(outputTerminalContent);
        }
    }

    function blinkCursor() {
        if (cursorTimer) {
            return;
        }
        cursorTimer = setInterval(function() {
            if (cursorVisible) {
                $("#outputTerminal").val(outputTerminalContent);
            } else {
                $("#outputTerminal").val(outputTerminalContent + '|');
            }
            cursorVisible = !cursorVisible;
        }, 500);
    }

    function appendOutput(content) {
        outputTerminalContent += content;
        $("#outputTerminal").val(outputTerminalContent);
        var outputElement = document.getElementById("outputTerminal");
        outputElement.scrollTop = outputElement.scrollHeight;
    }

    function setTabText(fileExt, content) {
        if (fileExt == 'output') {
            appendOutput(`\n${content}`);
        } else if (fileExt == 'md') {
            var result = window.md.render(content);
            if (state.project.current == 'frequent_flyer') {
                $("#tutorial").contents().find("#tutorial-content").html(result);
            } else {
                $("#get-started-md").html(result);
            }
        } else {
            data[fileExt].model = monaco.editor.createModel(content, fileFormat(fileExt));
            data[fileExt].state = null;
            // Changes the text of the Build button if Ruleset or DDL are edited
            if (fileExt != 'output') {
                data[fileExt].model.onDidChangeContent((event) => {
                    state.project.edits.add(fileExt);
                    setCtrlButtonLabel();
                });
            }
            setTab(fileExt);
        }
    }

    function getFileContents(filepath) {
        //GET request to grab filename content
        fetch(`/files/${filepath}`)
            .then(function (response) {
                return response.text();
            }).then(function (text) {
                setTabText(filepath.split('.')[1], text);
            });
    }

    // Updates thes state of the Build (ctrl) button depending on the run/build status.
    function setCtrlButtonLabel() {
        stopCursorBlink();
        if (state.session.loading) {
            $("#ctrl-button").html('Loading');
        } else if (state.project.edits.size > 0) {
            $("#ctrl-button").html('Save');
        } else if (state.project.runStatus == 'running') {
            blinkCursor();
            $("#outputTerminal").focus();
            $("#ctrl-button").html('Stop');
        } else if (state.project.buildStatus == 'success') {
            $("#ctrl-button").html('Run');
        } else if (state.project.buildStatus == 'building') {
            $("#ctrl-button").html('Cancel build');
        } else if (state.project.current) {
            $("#ctrl-button").html('Build');
        } else {
            $("#ctrl-button").html('No project loaded');
        }
    }

    window.mainMessageHandler = function (topic, payload) {
        let topicLevels = topic.split('/');

        if (topicLevels[1] == 'appUUID') {
            window.appUUID = payload;
            setCookie("appUUID", window.appUUID);
            window.publishToApp('ping', 'running');
            return;
        }

        if (topicLevels[1] == 'session') {
            if (payload == 'loading' && !state.session.loading) {
                state.session.loading = true;
            }
            else if (payload == 'loaded') {
                window.selectProject($("#scenario").attr("data-scenario"));
            }
            return;
        }

        if (topicLevels[1] == 'project') {
            switch (topicLevels[2].toString()) {
                case 'ready':
                    state.session.loading = false;
                    state.project.current = payload;
                    break;

                case 'build':
                    state.project.buildStatus = payload;
                    break;

                case 'program':
                    state.project.runStatus = payload;
                    break;

                default:
                    break;
            }
            setCtrlButtonLabel();
            return;
        }

        if (topicLevels[1] != 'editor') {
            return;
        }

        let fileName = topicLevels[2];
        let fileExt = fileName.split('.').pop();

        if (fileExt == 'output') {
            appendOutput(`\n${payload}`);
            return;
        }
        if (fileExt != 'ruleset' && fileExt != 'ddl' && fileExt != 'cpp') {
            return;
        }
        setTabText(fileExt, payload);
    }

    window.selectProject = function (projectName) {
        state.session.loading = true;
        state.project.current = projectName;
        window.publishToCoordinator("project/select", state.project.current);
    }

    // Sets the initital editor data before Coordinator loads,
    // creating the models that each tab will show
    function initEditorData(ruleset, ddl, cpp) {
        data.ruleset.model = monaco.editor.createModel(ruleset, 'cpp');
        data.ruleset.state = null;
        data.ddl.model = monaco.editor.createModel(ddl, 'sql');
        data.ddl.state = null;
        data.cpp.model = monaco.editor.createModel(cpp, 'cpp');
        data.cpp.state = null;
    }

    window.exitProject = function () {
        window.publishToCoordinator("project/exit", "exit");
        resetState();
        initEditorData('no ruleset file loaded', 'no ddl file loaded', 'no output yet');
        setCtrlButtonLabel();
    }

    // Loads page
    function load() {
        console.log('function load() ...', state.project.current);

        projects[state.project.current].forEach(element => {
            getFileContents(state.project.current + '/' + element);
        });

        initEditorData(
            "Loading...",
            "Loading...",
            "Loading..."
        );

        // Set Monaco editor theme
        monaco.editor.defineTheme('gaiaTheme', {
            base: 'vs',
            inherit: true,
            rules: [{ background: 'F4F6F8' }],
            colors: {
                'editor.background': '#F4F6F8',
            }
        });
        monaco.editor.setTheme('gaiaTheme');

        // Load editor
        editor = monaco.editor.create(document.getElementById('sandboxEditor'), {
            model: data.ruleset.model,
            automaticLayout: true,
            minimap: {
                enabled: false
            }
        });

        // Keeps track of current command.
        let curr_line = '';

        // Creates terminal input functionality based on key that is pressed
        $("#outputTerminal").on('keypress', function(e) {
            console.log('keypress: ' + String.fromCharCode(e.which));
            // Creates Enter functionality.
            if (e.which == 13) {
                if (curr_line == '') {
                    curr_line = ' ';
                }
                window.publishToCoordinator('editor/terminal_input', curr_line);
                curr_line = '';
                appendOutput("\n");
            // Creates Backspace functionality.
            } else if (e.which == 8) {
                if (curr_line) {
                    curr_line = curr_line.slice(0, curr_line.length - 1);
                    appendOutput("\b \b");
                }
            // Creates standard terminal input.
            } else {
                curr_line += String.fromCharCode(e.which);
                appendOutput(String.fromCharCode(e.which));
            }
        });
    }

    // Sets the new tab name onclick and sets the modal of that tabname
    function setTab(tabName) {
        var currentTabName = $(".selected-tab").attr("data-tab-name");
        if (currentTabName) {
            data[currentTabName].state = editor.saveViewState();
        }
        $(".editor-tab").removeClass("selected-tab");
        var newTab = $('[data-tab-name="' + tabName + '"]');
        newTab.addClass("selected-tab");
        editor.setModel(data[tabName].model);
        editor.restoreViewState(data[tabName].state);
        editor.focus();
    }

    window.generateUUID = function () { // By Briguy37
        let
            d = new Date().getTime(),
            d2 = (performance && performance.now && (performance.now() * 1000)) || 0;
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
            let r = Math.random() * 16;
            if (d > 0) {
                r = (d + r) % 16 | 0;
                d = Math.floor(d / 16);
            } else {
                r = (d2 + r) % 16 | 0;
                d2 = Math.floor(d2 / 16);
            }
            return (c == 'x' ? r : (r & 0x7 | 0x8)).toString(16);
        });
    }

    function setCookie(cookieName, value) {
        const expDate = new Date();
        expDate.setFullYear(expDate.getFullYear() + 10); // 10 year expiration time
        document.cookie = cookieName + "=" + value + ";expires=" + expDate.toUTCString() + ";path=/";
    }

    function getCookie(cookieName) {
        let name = cookieName + "=";
        let decodedCookie = decodeURIComponent(document.cookie);
        let ca = decodedCookie.split(';');
        for (let i = 0; i < ca.length; i++) {
            let c = ca[i];
            while (c.charAt(0) == ' ') {
                c = c.substring(1);
            }
            if (c.indexOf(name) == 0) {
                return c.substring(name.length, c.length);
            }
        }
        return null;
    }

    // Button functions
    $(".editor-tab").click(function () {
        if ($(this).attr("data-tab-name") != "run") {
            setTab($(this).attr("data-tab-name"));
        }
    });

    $("#ctrl-button").click(function () {
        if (state.session.loading) {
            return;
        }
        if (state.project.edits.size > 0) {
            state.project.edits.forEach(function (fileExt) {
                window.publishToCoordinator('editor/file/' + state.project.current + '.' + fileExt,
                    data[fileExt].model.getValue());
            });
            state.project.edits = new Set();
            setCtrlButtonLabel();
        } else if (state.project.runStatus == 'running'
            || state.project.buildStatus == 'building') {
            window.publishToCoordinator('project/stop', 'current');
        } else if (state.project.buildStatus == 'success') {
            $("#outputTerminal").empty();
            outputTerminalContent = '';
            window.messages.push(JSON.stringify({ topic: "reset", payload: "reset" }));
            window.publishToCoordinator('project/run', state.project.current);
        } else {
            window.publishToCoordinator('project/build', state.project.current);
        }
    })

    $("#reset-button").click(function () {
        if (confirm('This will reset all your changes. Continue?')) {
            setCookie("sandboxUUID", window.generateUUID());
            window.tour.restart();
            location.reload();
        }
    });

    $(".dropdown").click(function () {
        document.getElementById("dropdown-menu").classList.toggle("show")
    })

    window.onclick = function (event) {
        if (!event.target.matches('.dropdown')) {
            var dropdowns = document.getElementsByClassName("dropdown-content");

            for (let i = 0; i < dropdowns.length; i++) {
                var openDropdown = dropdowns[i];
                if (openDropdown.classList.contains('show')) {
                    openDropdown.classList.remove('show');
                }
            }
        }
    }

    $("#privacy-modal-confirm").click(function () {
        initTour();
    });

    $("#session-id-button").click(function () {
        prompt("Session ID (aka sandboxUUID)", "export SESSION_ID=" + window.sandboxUUID);
    });

    $("#test-button").click(function () {
        prompt("Subscribe to MQTT topics with this UUID:", window.appUUID);
    });

    $("#privacy-button").click(function () {
        $("#privacy-modal").show();
    });

    $("#get-started-button").click(function () {
        $("#get-started-modal").show();
    });

    $(".modal-close-button").click(function () {
        $(".modal").hide();
    });
})(jQuery);
