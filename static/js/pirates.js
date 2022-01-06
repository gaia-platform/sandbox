var bg_img = new Image();
var port_img = new Image();
var merchant_img = new Image();
var merchant_img_destroyed = new Image();
var navy_img = new Image();
var navy_img_attack = new Image();
var pirate_img = new Image();
var pirate_img_attack = new Image();
var pirate_img_destroyed = new Image();

// script for viewing multi-agent data
// the switchboard is pinged every X msec to get the most recent
//  position data and that is written to a canvas

////////////////////////////////////////////////////////////////////////
// switchboard interface

url = 'http://0.0.0.0:7111/get-positions/';

// stores content returned from switchboard
positionData = null;

// hit switchboard's endpoint to get latest data
function loadPositions() {
  fetch(url, { method: "GET", mode: 'cors', headers: {} })
    .then(response => response.json())
    .then(data =>  { if (data != null) positionData = data; });
}; 


////////////////////////////////////////////////////////////////////////
// main script interface

function init() {
  bg_img.src = 'static/img/pirate/ocean.jpg';
  port_img.src = 'static/img/pirate/port.png';
  //
  merchant_img.src = 'static/img/pirate/merchant.png';
  merchant_img_destroyed.src = 'static/img/pirate/merchant-x.png';
  //
  navy_img.src = 'static/img/pirate/navy.png';
  navy_img_attack.src = 'static/img/pirate/navy-attack.png';
  //
  pirate_img.src = 'static/img/pirate/pirate.png';
  pirate_img_attack.src = 'static/img/pirate/pirate-attack.png';
  pirate_img_destroyed.src = 'static/img/pirate/pirate-x.png';
  //
  window.requestAnimationFrame(draw_bg);
}


function draw_bg() {
  var ctx = document.getElementById('ocean-canvas').getContext('2d');
  ctx.globalCompositeOperation = 'destination-over';
  console.log("Drawing water");
  ctx.drawImage(bg_img, 0, 0);
  draw_ports();
}


function draw_ports() {
  console.log("Draw ports");
  if (positionData == null) {
    loadPositions();
    window.requestAnimationFrame(draw_ports, 1000);
    return;
  }
  var ctx = document.getElementById('port-canvas').getContext('2d');
  ctx.clearRect(0, 0, 1350, 850);
  for (let i=0; i<10; i++) {
    seaport = positionData[i];
    try {
      x = 0.001 * seaport['x'];
    } catch (error) {
      continue;
    }
    if (x < 0) {
      continue;
    }
    y = 0.001 * seaport['y'];
    // offset x and y for display. x,y is top-left of icon while we want it
    //  as center (icon is 20x25)
    x -= 10;
    y -= 12;
    ctx.drawImage(port_img, x, y);  
  }
  draw_ships();
}


function draw_ships() {
  var ctx = document.getElementById('ship-canvas').getContext('2d');
  ctx.globalCompositeOperation = 'destination-over';
  console.log("Draw ships");
  ctx.clearRect(0, 0, 1350, 850); // clear canvas
  for (let i=10; i<70; i++) {
    vessel = positionData[i];
    try {
      x = 0.001 * vessel['x'];
    } catch (error) {
      continue;
    }
    if (x < 0) {
      continue;
    }
    y = 0.001 * vessel['y'];
    //console.log(vessel);
    // offset x and y for display. x,y is top-left of icon while we want it
    //  as center (icon is 20x20)
    x -= 10;
    y -= 10;
    // determine ship type by ID
    if (i < 30) {   // merchant ?
      if (vessel['destroyed'] > 0) {
        ctx.drawImage(merchant_img_destroyed, x, y);
      } else {
        ctx.drawImage(merchant_img, x, y);
      }
    } else if (i < 50) {    // navy?
      if (vessel['target-id'] >= 0) {
        ctx.drawImage(navy_img_attack, x, y);
      } else {
        ctx.drawImage(navy_img, x, y);
      }
    } else if (i < 70) {    // pirate?
      if (vessel['destroyed'] > 0) {
        ctx.drawImage(pirate_img_destroyed, x, y);
      } else if (vessel['target-id'] >= 0) {
        ctx.drawImage(pirate_img_attack, x, y);
      } else {
        ctx.drawImage(pirate_img, x, y);
      }
    }
  }
  // prepare for next round
  loadPositions();
  setInterval(window.requestAnimationFrame(draw_bg), 1000);
}


init();

