(function ($) {
  "use strict";

  function receiveData() {
    $.get('/receive', function(data) {
      handleData(data);
    });
  }

  $(window).on('load', function () {
    sendData({ database: 'reset' });
  });

  function getTimeString(minutes) {
    var hours = Math.floor(minutes / 60);
    return (((hours % 12) == 0) ? '12' : (hours % 12).toString())
            + ':' + (((minutes % 60) == 0) ? '00' : (minutes % 60).toString()) + ' '
            + (hours >= 12 ? 'pm' : 'am');
  }

  function addSchedule(events, with_room_name) {
    var result = '';
    if (events.length > 0) {
      result = `            
        <div class="col-sm-12">
          <div class="box schedule">
            <h5>Schedule</h5>`;

      events.forEach(function(event) {
        result += '<p style="color:Black;">';
        result += getTimeString(event.start_timestamp) + ' - ';
        result += getTimeString(event.end_timestamp) + ' : ';
        if (with_room_name) {
          result += '</p><p style="color:Black;text-indent: 40px;">';
          result += event.name;
          result += ' in ' + event.room_name;
        } else {
          result += event.name;
        }
        result += '</p>';
      });
      result += `
          </div>
        </div>`;
    }
    return result;
  }

  function addOtherInfo(person) {
    var result = `
      <div class="col-sm-6">
        <div style="text-align: center;" class="box other" data-person-id="`
          + person.person_id + `">
          <h5>Other</h5>
          <i class="fas fa-parking`;
    if (person.parked) {
      result += ' selected';
    }
    result += `"></i>
          <i class="fas fa-wifi`;
    if (person.on_wifi) {
      result += ' selected';
    }
    result += `"></i>
        </div>
      </div>`;

    return result;
  }

  function addBadgeIn(person, building) {
    var result = `
      <div class="col-sm-6">
        <div style="text-align: center;" class="box move" data-person-id="` 
          + person.person_id + `" data-building-id="` + building.building_id + `">
          <h5>HQ Front Door</h5>`;
    if (!person.stranger) {
      result += '<i class="fas fa-id-badge';
      if (person.badged) {
        result += ' selected';
      }
      result += '"></i>';
    }
    result += `
          <i class="fas fa-laugh"></i>
        </div>
      </div>`;
    return result;
  }

  function addLocationNav(person, room) {
    return `
      <div class="col-sm-6">
        <div style="text-align: center;" class="box move" data-person-id="` 
          + person.person_id + `" data-room-id="` + room.room_id 
          + `" data-building-id="` + cachedData.buildings[0].building_id + `">
          <h5 class="room-name">` + room.name + `</h5>
          <i class="fas fa-laugh"></i>
          <i class="fas fa-sign-out-alt"></i>
        </div>
      </div>`;
  }

  function addPerson(person, room) {
    var result = `
      <div id="person_` + person.first_name.toLowerCase() + `" class="box person">
        <div class="container">
          <div class="row">
            <div class="col-sm-12">
              <h4>` + person.first_name + ` - `;
    if (person.employee) {
      result += 'Employee';
    } else if (person.visitor) {
      result += 'Visitor';
    } else if (person.stranger) {
      result += 'Stranger';
    }
    result += `</h4>
            </div>
          </div>
          <div class="row">`;
    if (person.inside_room) {
      result += addLocationNav(person, room);
    } else if (!room) {
      result += addLocationNav(person, cachedData.buildings[0].rooms[0]);
    } else {
      result += addBadgeIn(person, cachedData.buildings[0])
    }
    result += addOtherInfo(person);
    result += `
          </div>
          <div class="row">`;
    result += addSchedule(person.events, true);
    result += `
          </div>
        </div>
      </div>`;
    return result;
  }

  function addLocation(room) {
    var result = `
      <div class="row">
        <div class="col-sm-12">
          <div class="box location">
            <h4>` + room.name + `</h4>
            <div id="` + room.name.toLowerCase().replace(/\s/g, '') + `">`;

    if (room.people) {
      room.people.forEach(function(person) {
        result += addPerson(person, room);
      });
    }
    result += addSchedule(room.events);
    result += `
            </div>
          </div>
        </div>
      </div>
    `;
    
    return result;
  }

  function addBuilding(building) {
    var newElem = `
      <div class="row">
        <div class="col-sm-12">
          <div class="box building">
            <h4>` + building.name + `</h4>
            <div id="building">`;

    if (building.people) {
      building.people.forEach(function(person) {
        newElem += addPerson(person);
      });
    }

    building.rooms.forEach(function(room) {
      newElem += addLocation(room);
    });
    newElem += `
            </div>
          </div>
        </div>
      </div>`;

    $("#locations").append(newElem);
  }

  function addPeople(people) {
    $("#people").empty();
    if (people) {
      people.forEach(function(person) {
        $("#people").append(addPerson(person, cachedData.buildings[0].rooms[0]));
      });
    }
  }

  var cachedData = null;

  function handleData(data) {
    //alert(data);
    var parsedData = JSON.parse(data);
    if (parsedData.data && parsedData.data == 'none') {
      return; 
    }

    if (parsedData.buildings) {
      cachedData = parsedData;
      $("#locations").empty();
      addBuilding(parsedData.buildings[0]);
      addPeople(parsedData.people);
    } else if (parsedData.alert) {
      $("#message-output").text(parsedData.alert);
      $("#messages").attr("hidden",false);
    }
    receiveData();
  }

  function nextRoom(roomId) {
    var i = 0;
    while (i < cachedData.buildings[0].rooms.length
          && cachedData.buildings[0].rooms[i].room_id != roomId) {
      i++;
    }
    if (++i >= cachedData.buildings[0].rooms.length) {
      i = 0;
    }
    return cachedData.buildings[0].rooms[i];
  }

  $(document).on("click", ".room-name", function() {
    var newRoom = nextRoom(parseInt($(this).parent().attr("data-room-id")));
    $(this).parent().attr("data-room-id", newRoom.room_id);
    $(this).html(newRoom.name);
  });

  $(document).on("click", "#location-time", function() {
    var minutes = parseInt($("#time").attr("data-minutes")) + 30;
    $("#time").attr("data-minutes", minutes.toString());
    $("#time").text(getTimeString(minutes));
    sendData({ time: minutes });
  });

  function sendScan(scan_type, elem) {
    sendData({ scan: {
      scan_type: scan_type,
      person_id: parseInt(elem.attr("data-person-id")),
      building_id: parseInt(elem.attr("data-building-id")),
      room_id: parseInt(elem.attr("data-room-id"))
      }
    });
  }

  $(document).on("click", ".fas", function() {
    $("#messages").attr("hidden",true);
  });

  $(document).on("click", "#messages", function() {
    $("#messages").attr("hidden",true);
  });

  $(document).on("click", ".fa-id-badge", function() {
    sendScan('badge', $(this).parent());
  });

  $(document).on("click", ".fa-laugh", function() {
    sendScan('face', $(this).parent());
  });

  $(document).on("click", ".fa-sign-out-alt", function() {
    sendScan('leaving', $(this).parent());
  });

  $(document).on("click", ".fa-parking", function() {
    if ($(this).hasClass("selected")) {
      sendScan('vehicle_departing', $(this).parent());
    } else {
      sendScan('vehicle_entering', $(this).parent());
    }
  });

  $(document).on("click", ".fa-wifi", function() {
    if ($(this).hasClass("selected")) {
      sendScan('leaving_wifi', $(this).parent());
    } else {
      sendScan('joining_wifi', $(this).parent());
    }
  });

  function postMessage(message, cb) {
    $.ajax({
      url: '/send',
      type: 'post',
      dataType: 'json',
      contentType: 'application/json',
      data: message
    }).done(cb);
  }

  function sendData(data) {
    postMessage(JSON.stringify(data), function() {
      postMessage('{ "database" : "get" }', receiveData);
    });
  }

})(jQuery);

