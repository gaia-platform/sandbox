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
      storedAppUUID = window.generateUUID();
      setCookie("appUUID", storedAppUUID);

      // Show privacy message (since the cookie is new)
      $("#privacy-modal").show();
    }

    window.sandboxUUID = storedSandboxUuid;
    window.appUUID = storedAppUUID;
    console.log("App ID: " + window.appUUID);
    window.publishToCoordinator("browser", "refresh");
    window.subscribeToTopic("editor/#");
    window.subscribeToTopic("appUUID");
  });

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

  window.mainMessageHandler = function (topic, payload) {
    let topicLevels = topic.split('/');

    if (topicLevels[1] == 'appUUID') {
      window.appUUID = payload;
      setCookie("appUUID", window.appUUID);
      window.publishToApp("ping", "running");
      return;
    }

    if (topicLevels[1] != 'editor') {
      return;
    }

    let fileName = topicLevels[2];
    if (fileName != 'ruleset' && fileName != 'ddl' && 'output') {
      return;
    }

    if (topicLevels[3] == 'append') {
      // append text to appropriate window
    }

    data[fileName].model = monaco.editor.createModel(payload, fileFormat(fileName));
    data[fileName].state = null;
    setTab(fileName);
  }

  function load() {
    data.ruleset.model = monaco.editor.createModel('no ruleset file loaded', 'cpp');
    data.ddl.model = monaco.editor.createModel('no ddl file loaded', 'sql');
    data.output.model = monaco.editor.createModel('no output yet', 'text');

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

  $("#run-button").click(function () {
    // window.publishToCoordinator("editor/ddl", data.ddl.model.getValue());
  })

  $("#reset-button").click(function () {
    // Reset Current simulation
  });

  $("#test-button").click(function () {
    alert("export REMOTE_CLIENT_ID=" + window.sandboxUUID);
  });

  $("#privacy-button").click(function () {
    $("#privacy-modal").show();
  });
  $(".modal-close-button").click(function () {
    $("#privacy-modal").hide();
  });
})(jQuery);

