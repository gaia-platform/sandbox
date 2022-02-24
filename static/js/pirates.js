var backgroundImage = new Image();
var portImage = new Image();
var merchantImage = new Image();
var merchantDestroyedImage = new Image();
var navyImage = new Image();
var navyAttackImage = new Image();
var pirateImage = new Image();
var pirateAttackImage = new Image();
var pirateDestroyedImage = new Image();

// Script for viewing multi-agent data
// The pirate switchboard is pinged every X msec to get the most recent
//  position data and that is written to a canvas.

////////////////////////////////////////////////////////////////////////
// switchboard interface

url = 'http://0.0.0.0:7111/get-positions/';

// Stores content returned from switchboard
positionData = null;

// Hit switchboard's endpoint to get latest data
function loadPositions() {
  fetch(url, { method: "GET", mode: 'cors', headers: {} })
    .then(response => response.json())
    .then(data =>  { if (data != null) positionData = data; });
}; 


////////////////////////////////////////////////////////////////////////
// main script interface

function init() {
  backgroundImage.src = 'static/img/pirate/ocean.jpg';
  portImage.src = 'static/img/pirate/port.png';
  //
  merchantImage.src = 'static/img/pirate/merchant.png';
  merchantDestroyedImage.src = 'static/img/pirate/merchant-x.png';
  //
  navyImage.src = 'static/img/pirate/navy.png';
  navyAttackImage.src = 'static/img/pirate/navy-attack.png';
  //
  pirateImage.src = 'static/img/pirate/pirate.png';
  pirateAttackImage.src = 'static/img/pirate/pirate-attack.png';
  pirateDestroyedImage.src = 'static/img/pirate/pirate-x.png';
  //
  window.requestAnimationFrame(draw_bg);
}


function draw_bg() {
  var ctx = document.getElementById('ocean-canvas').getContext('2d');
  ctx.globalCompositeOperation = 'destination-over';
  ctx.drawImage(backgroundImage, 0, 0);
  draw_ports();
}


function draw_ports() {
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
    ctx.drawImage(portImage, x, y);  
  }
  draw_ships();
}


function draw_ships() {
  var ctx = document.getElementById('ship-canvas').getContext('2d');
  ctx.globalCompositeOperation = 'destination-over';
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
    // offset x and y for display. x,y is top-left of icon while we want it
    //  as center (icon is 20x20)
    x -= 10;
    y -= 10;
    // determine ship type by ID
    if (i < 30) {   // merchant ?
      if (vessel['destroyed'] > 0) {
        ctx.drawImage(merchantDestroyedImage, x, y);
      } else {
        ctx.drawImage(merchantImage, x, y);
      }
    } else if (i < 50) {    // navy?
      if (vessel['target-id'] >= 0) {
        ctx.drawImage(navyAttackImage, x, y);
      } else {
        ctx.drawImage(navyImage, x, y);
      }
    } else if (i < 70) {    // pirate?
      if (vessel['destroyed'] > 0) {
        ctx.drawImage(pirateDestroyedImage, x, y);
      } else if (vessel['target-id'] >= 0) {
        ctx.drawImage(pirateAttackImage, x, y);
      } else {
        ctx.drawImage(pirateImage, x, y);
      }
    }
  }
  // prepare for next round
  loadPositions();
  setInterval(window.requestAnimationFrame(draw_bg), 1000);
}


init();

