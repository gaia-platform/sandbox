(function ($) {
  "use strict";

  // Setup HTML
  const state = {};
  function update() {
    document.querySelectorAll("[data-name='div-1']").forEach((el) => {
      el.space = 20;
    });

    document.querySelectorAll("[data-name='a-1']").forEach((el) => {
      el.aspectRatio = 0.1682;
      el.fitContent = false;
    });

    document.querySelectorAll("[data-name='a-2']").forEach((el) => {
      el.openLinkInNewTab = true;
    });

    document.querySelectorAll("[data-name='a-3']").forEach((el) => {
      el.openLinkInNewTab = true;
    });

    document.querySelectorAll("[data-name='div-2']").forEach((el) => {
      el.space = 20;
    });

    document.querySelectorAll("[data-name='div-3']").forEach((el) => {
      el.space = 20;
    });
  }

  // Update with initial state on first load
  update();

  $(window).on('load', function () {
    // Load Monaco Editor
    require.config({ paths: { vs: "static/lib/monaco/vs" } });

    require(['vs/editor/editor.main'], function () {
      load();
    });

    // Generate UUID
    window.sandboxUuid = "asdf"; //generateUUID();
    console.log("Sandbox UUID: " + window.sandboxUuid);
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
    data.ruleset.model = monaco.editor.createModel('console.log("hi")', 'cpp');
    data.ddl.model = monaco.editor.createModel('What the', 'sql');
    data.output.model = monaco.editor.createModel('This is output', 'text');

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

  // Button functions
  $(".editor-tab").click(function () {
    setTab($(this).attr("data-tab-name"));
  });

  $("#reset").click(function () {
    location.reload();
  });

  $("#privacy-button").click(function () {
    $("#privacy-modal").show();
  });
  $(".modal-close-button").click(function () {
    $("#privacy-modal").hide();
  });
})(jQuery);

