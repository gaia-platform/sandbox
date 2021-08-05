(function ($) {
  "use strict";

  $(window).on('load', function () {
    // Load Monaco Editor
    require.config({ paths: { vs: "static/lib/monaco/vs" } });

    require(['vs/editor/editor.main'], function () {
      load();
    });

    // Generate UUID and store in cookie
    let storedUuid = getCookie();
    if (storedUuid === "") {
      const expDate = new Date();
      expDate.setFullYear(expDate.getFullYear() + 1);
      storedUuid = "asdf"; //generateUUID();
      document.cookie = "sandboxUUID=" + storedUuid + ";expires=" + expDate.toUTCString() + ";path=/";
    }
    window.sandboxUuid = storedUuid
    console.log("Sandbox UUID: " + window.sandboxUuid);
    window.publishData("sandbox_coordinator/browser", window.sandboxUuid);
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

  const generateUUID = () => { // By Briguy37
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
  };

  function getCookie() {
    let name = "sandboxUUID=";
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
    return "";
  }

  // Button functions
  $(".editor-tab").click(function () {
    setTab($(this).attr("data-tab-name"));
  });

  $("#run-button").click(function () {
    // Run code
  })

  $("#reset-button").click(function () {
    // Reset Current simulation
  });

  $("#privacy-button").click(function () {
    $("#privacy-modal").show();
  });
  $(".modal-close-button").click(function () {
    $("#privacy-modal").hide();
  });
})(jQuery);

