(function ($) {
  "use strict";

  $(window).on('load', function () {
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
    }
    let storedAppUUID = getCookie("appUUID");
    if (!storedAppUUID) {
      storedAppUUID = "not set yet";
      setCookie("appUUID", storedAppUUID);
    }

    window.sandboxUUID = storedSandboxUuid;
    window.appUUID = storedAppUUID;

    window.publishToCoordinator("browser", "refresh");
    window.subscribeToTopic("editor/#", false);
    window.subscribeToTopic("project/#", false);
    window.subscribeToTopic("session/#", false);
    window.subscribeToTopic("appUUID", false);
  });

  var currentProject = null;
  var sessionLoading = false;
  var sessionLoadCountdown = 0;
  var projectBuildState = 'unknown';
  var projectRunState = 'stopped';
  var editsExist = false;
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
    output: {
      model: null,
      state: null
    }
  };

  function fileFormat(fileName) {
    switch (fileName) {
      case 'ruleset': return 'cpp';
      case 'ddl': return 'sql';

      default:
        break;
    }
    return 'text';
  }

  function setTabText(fileExt, content) {
    data[fileExt].model = monaco.editor.createModel(content, fileFormat(fileExt));
    data[fileExt].state = null;
    if (fileExt != 'output') {
      data[fileExt].model.onDidChangeContent((event) => {
        editsExist = true;
        setCtrlButtonLabel();
      });
    }
    setTab(fileExt);
  }

  function appendTabText(fileExt, content) {
    data[fileExt].model = monaco.editor.createModel(data[fileExt].model.getValue() + content, fileFormat(fileExt));
    setTab(fileExt);
    editor.revealLine(editor.getModel().getLineCount())
  }

  function sessionRestoreMessages() {
    if (sessionLoading) {
      if (sessionLoadCountdown > 0) {
        setTabText('output', 'Restoring session.\nEstimated time remaining: '
            + Math.floor(sessionLoadCountdown / 60).toString() + ':'
            + (sessionLoadCountdown % 60 < 10 ? '0' : '')
            + (sessionLoadCountdown % 60).toString()
            + '\n');
      } else if (sessionLoadCountdown == 0) {
        setTabText('output', 'Taking longer than expected.');
      } else {
        appendTabText('output', '.');
      }
      sessionLoadCountdown -= 1;
      setTimeout(sessionRestoreMessages, 1 * 1000);
    }
  }

  function setCtrlButtonLabel() {
    if (editsExist) {
      $("#ctrl-button").html('Save');
    } else if (projectRunState == 'running') {
      $("#ctrl-button").html('Stop');   
    } else if (projectBuildState == 'success') {
      $("#ctrl-button").html('Run');
    } else {
      $("#ctrl-button").html('Build');
    }
  }

  window.mainMessageHandler = function (topic, payload) {
    let topicLevels = topic.split('/');

    if (topicLevels[1] == 'appUUID') {
      window.appUUID = payload;
      setCookie("appUUID", window.appUUID);
      window.publishToApp("ping", "running");
      return;
    }

    if (topicLevels[1] == 'session') {
      sessionLoading = true;
      sessionLoadCountdown = 2 * 60;
      sessionRestoreMessages();
      return;
    }

    if (topicLevels[1] == 'project') {
      if (topicLevels[2] == 'selected') {
        window.publishToCoordinator("editor/req", currentProject + ".ddl");
        window.publishToCoordinator("editor/req", currentProject + ".ruleset");
      } else if (topicLevels[2] == 'build') {
        projectBuildState = payload;
        setCtrlButtonLabel();
      }
      return;
    }

    if (topicLevels[1] != 'editor') {
      return;
    }

    let fileName = topicLevels[2];
    let fileExt = fileName.split('.').pop();
    if (fileExt != 'ruleset' && fileExt != 'ddl' && fileExt != 'output') {
      return;
    }

    if (sessionLoading) {
      sessionLoading = false;
      setTabText('output', '');
    }

    if (topicLevels[3] == 'append') {
      appendTabText(fileExt, payload);
    }
    else {
      setTabText(fileExt, payload);
    }
  }

  window.selectProject = function (projectName) {
    currentProject = projectName.replace("_template", "");
    window.publishToCoordinator("project/select", currentProject);
  }

  function initEditorData(ruleset, ddl, output) {
    data.ruleset.model = monaco.editor.createModel(ruleset, 'cpp');
    data.ruleset.state = null;
    data.ddl.model = monaco.editor.createModel(ddl, 'sql');
    data.ddl.state = null;
    data.output.model = monaco.editor.createModel(output, 'text');
    data.output.state = null;
  }

  window.exitProject = function () {
    currentProject = null;
    window.publishToCoordinator("project/exit", "exit");
    initEditorData('no ruleset file loaded', 'no ddl file loaded', 'no output yet');
    setTab('output');
  }

  function load() {
    initEditorData('initializing...', 'initializing...', 'initializing...');

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
      minimap: {
        enabled: false
      }
    });
  }

  function setTab(tabName) {
    var currentTabName = $(".selected-tab").attr("data-tab-name");
    data[currentTabName].state = editor.saveViewState();
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
    setTab($(this).attr("data-tab-name"));
  });

  $("#ctrl-button").click(function () {
    window.publishToCoordinator("project/build", currentProject);
/*    if (editsExist) {
      window.publishToCoordinator("editor/ddl", data.ddl.model.getValue());
      window.publishToCoordinator("editor/ruleset", data.ruleset.model.getValue());
      editsExist = false;
    } else if (projectRunState == 'running') {
      $("#ctrl-button").html('Stop');   
    } else if (projectBuildState == 'success') {
      $("#ctrl-button").html('Run');
    } else {
      $("#ctrl-button").html('Build');
    }
    */    
  })

  $("#reset-button").click(function () {
    prompt("Remote client ID (aka sandboxUUID)", "export REMOTE_CLIENT_ID=" + window.sandboxUUID);
  });

  $("#test-button").click(function () {
    prompt("Subscribe to MQTT topics with this UUID:", window.appUUID);
  });

  $("#privacy-button").click(function () {
    $("#privacy-modal").show();
  });
  $(".modal-close-button").click(function () {
    $("#privacy-modal").hide();
  });
})(jQuery);
