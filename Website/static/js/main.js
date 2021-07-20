(function ($) {
  "use strict";

  $(window).on('load', function () {
    require.config({ paths: { vs: "static/lib/monaco/vs" } });

    require(['vs/editor/editor.main'], function () {
      load();
    });
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

  $(".tab").click(function() {
    setTab($(this).attr("data-tab-name"));
  });

  $("#reset").click(function() {
    location.reload();
  });

})(jQuery);

