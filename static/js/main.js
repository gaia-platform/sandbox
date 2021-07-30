(function ($) {
  "use strict";

  $(window).on('load', function () {
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
    var currentTabName = $(".active").attr("data-tab-name");
    data[currentTabName].state = editor.saveViewState();
    $(".tab").removeClass("active");
    var newTab = $('[data-tab-name="' + tabName + '"]');
    newTab.addClass("active");
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

  $(".tab").click(function () {
    setTab($(this).attr("data-tab-name"));
  });

  $("#reset").click(function () {
    location.reload();
  });

})(jQuery);

