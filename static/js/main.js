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
    window.publishToCoordinator("project/stop", "current");
    window.subscribeToTopic("editor/#", false);
    window.subscribeToTopic("project/#", false);
    window.subscribeToTopic("session", false);
    window.subscribeToTopic("appUUID", false);
  });

  var get_started = "Get started guide currently unavailable";

  var state = {
    project: {
      current: null,
      buildStatus: 'unknown',
      runStatus: 'stopped',
      edits: new Set()
    },
    session: {
      loading: false,
      loadCountdown: 0
    }
  }
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
        state.project.edits.add(fileExt);
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
    if (state.session.loading) {
      if (state.session.countdown > 0) {
        setTabText('output', 'Restoring session.\nEstimated time remaining: '
            + Math.floor(state.session.countdown / 60).toString() + ':'
            + (state.session.countdown % 60 < 10 ? '0' : '')
            + (state.session.countdown % 60).toString()
            + '\n');
      } else if (state.session.countdown == 0) {
        setTabText('output', 'Taking longer than expected.');
      } else {
        appendTabText('output', '.');
      }
      state.session.countdown -= 1;
      setTimeout(sessionRestoreMessages, 1 * 1000);
    }
  }

  function setCtrlButtonLabel() {
    if (state.project.edits.size > 0) {
      $("#ctrl-button").html('Save');
    } else if (state.project.runStatus == 'running') {
      $("#ctrl-button").html('Stop');
    } else if (state.project.buildStatus == 'success') {
      $("#ctrl-button").html('Run');
    } else if (state.project.buildStatus == 'building') {
      $("#ctrl-button").html('Cancel build');
    } else {
      $("#ctrl-button").html('Build');
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
        state.session.countdown = 2 * 60;
        sessionRestoreMessages();
      }
      else if (payload == 'loaded' && state.session.loading) {
        state.session.loading = false;
        window.selectProject(state.project.current);
      }
      return;
    }

    if (topicLevels[1] == 'project') {
      switch (topicLevels[2].toString()) {
        case 'ready':
          state.project.current = payload;
          setTabText('output', 'Ready');
          window.publishToCoordinator("editor/req", state.project.current + ".ddl");
          window.publishToCoordinator("editor/req", state.project.current + ".ruleset");
          window.publishToCoordinator("editor/req", "get_started.md");
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
    if (fileExt != 'ruleset' && fileExt != 'ddl' && fileExt != 'output' && fileExt != 'md') {
      return;
    }

    if (fileExt == 'md') {
      get_started = payload;
    } else if (topicLevels[3] == 'append') {
      appendTabText(fileExt, payload);
    }
    else {
      setTabText(fileExt, payload);
    }
  }

  window.selectProject = function (projectName) {
    state.project.current = projectName.replace("_template", "");
    window.publishToCoordinator("project/select", state.project.current);
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
    state.project.current = null;
    window.publishToCoordinator("project/exit", "exit");
    initEditorData('no ruleset file loaded', 'no ddl file loaded', 'no output yet');
    setTab('output');
  }

  function load() {
    initEditorData('Loading...', 'Loading...', 'Loading...');

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
    if (state.project.edits.size > 0) {
      state.project.edits.forEach (function(fileExt) {
        window.publishToCoordinator('editor/file/' + state.project.current + '.' + fileExt,
          data[fileExt].model.getValue());
      });
      state.project.edits = new Set();
      setCtrlButtonLabel();
    } else if (state.project.runStatus == 'running'
          || state.project.buildStatus == 'building') {
      window.publishToCoordinator('project/stop', 'current');
    } else if (state.project.buildStatus == 'success') {
      window.messages.push(JSON.stringify({ topic: "reset", payload: "reset" }));
      window.publishToCoordinator('project/run', state.project.current);
    } else {
      window.publishToCoordinator('project/build', state.project.current);
    }
  })

  $("#reset-button").click(function () {
    prompt("Remote client ID (aka sandboxUUID)", "export REMOTE_CLIENT_ID=" + window.sandboxUUID);
  });

  $("#test-button").click(function () {
    prompt("Subscribe to MQTT topics with this UUID:", window.appUUID);
  });

  $("#test-me").click(function () {
    document.getElementById('godot').contentDocument.location.reload(true);
  });

  $("#privacy-button").click(function () {
    $("#privacy-modal").show();
  });

  $("#get-started-button").click(function () {
    var result = window.md.render(get_started);
    $("#get-started-md").html(result);
    $("#get-started-modal").show();
  });

  $(".modal-close-button").click(function () {
    $(".modal").hide();
  });
})(jQuery);
