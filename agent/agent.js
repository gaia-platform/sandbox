// Imports
const { spawn, exec } = require('child_process');
const AWS = require('aws-sdk');
const AWSIoTData = require('aws-iot-device-sdk');
const fs = require('fs');

console.log('Loaded AWS SDK for JavaScript and AWS IoT SDK for Node.js');

//// Variables
/// MQTT
var awsConfig = {
   poolId: 'us-west-2:167b474a-b678-4271-8f1e-77f84aa530f7', // 'YourCognitoIdentityPoolId'
   host: 'a31gq30tvzx17m-ats.iot.us-west-2.amazonaws.com', // 'YourAwsIoTEndpoint', e.g. 'prefix.iot.us-east-1.amazonaws.com'
   region: 'us-west-2' // 'YourAwsRegion', e.g. 'us-east-1'
};

var coordinatorName = process.env.COORDINATOR_NAME || 'sandbox_coordinator';
var agentId = process.env.AGENT_ID;
var sessionId = process.env.SESSION_ID;

process.env.REMOTE_CLIENT_ID = sessionId;

const sendKeepAliveInterval = 1;  // in minutes
const receiveKeepAliveInterval = 3;  // in minutes
//const projectNames = ['access_control', 'amr_swarm'];
const projectNames = ['amr_swarm'];
var gaiaChild = null;
var cmakeBuild = null;
var makeBuild = null;
var projectProcess = null;
var receiveKeepAliveTimeout;

//// Setup AWS and MQTT
AWS.config.region = awsConfig.region;

AWS.config.credentials = new AWS.CognitoIdentityCredentials({
   IdentityPoolId: awsConfig.poolId
});

var mqttClient;

function connect(credentials)
{
   /// Config and connect MQTT
   mqttClient = AWSIoTData.device({
      region: AWS.config.region,
      host: awsConfig.host,
      clientId: agentId,
      protocol: 'wss',
      maximumReconnectTimeMs: 8000,
      debug: true,
      accessKeyId: credentials.AccessKeyId,
      secretKey: credentials.SecretKey,
      sessionToken: credentials.SessionToken
   });

   // Install handlers
   mqttClient.on('connect', mqttClientConnectHandler);
   mqttClient.on('reconnect', mqttClientReconnectHandler);
   mqttClient.on('message', mqttClientMessageHandler);
}

/// Cognito authentication
var cognitoIdentity = new AWS.CognitoIdentity();
AWS.config.credentials.get(function (err, data) {
   if (!err) {
      console.log('retrieved identity: ' + AWS.config.credentials.identityId);
      var params = {
         IdentityId: AWS.config.credentials.identityId
      };
      cognitoIdentity.getCredentialsForIdentity(params, function (err, data) {
         if (!err) {
            connect(data.Credentials);
         } else {
            console.log('error retrieving credentials: ' + err);
         }
      });
   } else {
      console.log('error retrieving identity:' + err);
   }
});

function exitAgent() {
   if (gaiaChild) {
      gaiaChild.kill();
      gaiaChild = null;
   }
   process.exit(0);
}

function publishToEditor(file, contents) {
   console.log('publish to:' + sessionId + "/editor/" + file);
   mqttClient.publish(sessionId + "/editor/" + file, contents);
}

function publishToCoordinator(action, payload) {
   mqttClient.publish(coordinatorName + "/" + agentId + "/agent/" + action, payload);
}

function sendKeepAlive() {
   publishToCoordinator('keepAlive', agentId);
   setTimeout(sendKeepAlive, sendKeepAliveInterval * 60 * 1000);
}

function receiveKeepAlive() {
   clearTimeout(receiveKeepAliveTimeout);
   receiveKeepAliveTimeout = setTimeout(exitAgent, receiveKeepAliveInterval * 60 * 1000);
}

//// MQTT functions
function mqttClientConnectHandler() { // Connection handler
   console.log('connect, clientId: ' + agentId);

   //
   // Subscribe to our current topic.
   //
   mqttClient.subscribe(agentId + '/#');
   publishToCoordinator('connected', agentId);
   setTimeout(sendKeepAlive, sendKeepAliveInterval * 60 * 1000);
   if (sessionId == 'standby') {
      console.log('do builds... TODO: not actually doing the builds');
      /* this seems to be causing problems...
      projectNames.forEach(function(projectName){
         buildProject(projectName);
      });
      */
   } else {
      mqttClient.publish(sessionId + '/session', 'loaded');      
   }
}

function mqttClientReconnectHandler() { // Reconnection handler
   console.log("reconnect");
}

function sendFile(projectName, fileName) {
   fs.readFile('templates/' + projectName + '_template/src/' + fileName, 'utf8' , (err, data) => {
      if (err) {
        console.error(err);
        return;
      }
      publishToEditor(fileName, data);
   });
}

function saveFile(projectName, fileName, content) {
   fs.writeFile('templates/' + projectName + '_template/src/' + fileName, content, 'utf8', (err) => {
      if (err) {
         console.error(err);
         return;
      }
      console.log(fileName + ' has been saved');
   });
   var fileNameParts = fileName.split('.');
   if (fileNameParts.length == 2 && fileNameParts[1] == 'ddl') {
      resetGaia();
   }
   mqttClient.publish(sessionId + '/project/build', 'dirty');
}

function cleanProjects() {
   projectNames.forEach(projectName => {
      console.log('rm -r templates/' + projectName + '_template/build/gaia_generated');
      exec('rm -r templates/' + projectName + '_template/build/gaia_generated');
      exec('mkdir -p templates/' + projectName + '_template/build');
      console.log('from directory: templates/' + projectName + '_template/build');
      console.log('cmake ..');
      cmakeBuild = spawn('cmake', ['..'], { cwd: 'templates/' + projectName + '_template/build' });
      cmakeBuild.stdout.on('data', (chunk) => {
         console.log(chunk.toString());
      });
      cmakeBuild.stdout.on('error', (error) => {
         console.log(error);
      });
      cmakeBuild.on('close', (code) => {
         console.log(`cmake child process exited with code ${code}`);
         cmakeBuild = null;
      });
   });
}

function resetGaia() {
   cleanProjects();
   if (gaiaChild) {
      gaiaChild.kill();
      gaiaChild = null;
   }
   console.log('rm -r ~/.local/gaia/db/');
   exec('rm -r ~/.local/gaia/db/', (error, stdout, stderr) => {
      console.error(`error: ${error}`);
      console.log(`stdout: ${stdout}`);
      console.error(`stderr: ${stderr}`);
      console.log('spawn gaia_db_server');
      gaiaChild = spawn('gaia_db_server', ['--data-dir', '~/.local/gaia/db']);
      gaiaChild.stdout.on('data', (chunk) => {
         console.log(chunk);
      });
      gaiaChild.stdout.on('error', (error) => {
         console.log(error);
      });
      gaiaChild.on('close', (code) => {
         console.log(`gaia_db_server child process exited with code ${code}`);
         gaiaChild = null;
      });
   });
}

function stopProcesses() {
   if (cmakeBuild) {
      cmakeBuild.kill();
      cmakeBuild = null;
   }
   if (makeBuild) {
      makeBuild.kill();
      makeBuild = null;
      mqttClient.publish(sessionId + '/project/build', 'cancelled');
   }
   if (projectProcess) {
      projectProcess.kill();
      projectProcess = null;
      mqttClient.publish(sessionId + '/project/program', 'stopped');
   }
}

function runProject(projectName) {
   projectProcess = exec('bash ../start_amr_swarm.sh',
      {
         cwd: 'templates/' + projectName + '_template/build',
         env: { 'SESSION_ID': sessionId }
      });
   publishToEditor('output/append', 'Running application...\n');
   mqttClient.publish(sessionId + '/project/program', 'running');
   projectProcess.stderr.on('data', (chunk) => {
      publishToEditor('output/append', chunk);
      console.log(chunk.toString());
   });
   projectProcess.stdout.on('data', (chunk) => {
      publishToEditor('output/append', chunk);
      console.log(chunk.toString());
   });
   projectProcess.stdout.on('error', (error) => {
      console.log(error);
   });
   projectProcess.on('close', (code) => {
      console.log(`child process exited with code ${code}`);
      projectProcess = null;
      mqttClient.publish(sessionId + '/project/program', 'stopped');
   });
}

function buildProject(projectName) {
   if (!gaiaChild) {
      resetGaia();
   }
   console.log(projectName + ' build started...');
   publishToEditor('output', 'New build started\n');
   mqttClient.publish(sessionId + '/project/build', 'building');
   makeBuild = spawn('make', { cwd: 'templates/' + projectName + '_template/build' });
   makeBuild.stderr.on('data', (chunk) => {
      publishToEditor('output/append', chunk);
      console.log(chunk.toString());
   });
   makeBuild.stdout.on('data', (chunk) => {
      publishToEditor('output/append', chunk);
      console.log(chunk.toString());
   });
   makeBuild.stdout.on('error', (error) => {
      console.log(error);
   });
   makeBuild.on('close', (code) => {
      console.log(`child process exited with code ${code}`);
      makeBuild = null;
      mqttClient.publish(sessionId + '/project/build', code == 0 ? 'success' : 'failed');
   });
}

function mqttClientMessageHandler(topic, payload) { // Message handler
   console.log('message: ' + topic + ' payload: ' + payload);
   var topicTokens = topic.split('/');
   if (topicTokens.length < 3) {
      if (topicTokens[1] == 'sessionId') {
         sessionId = payload;
         mqttClient.publish(sessionId + '/session', 'loaded');
         return;
      }
      switch (payload.toString()) {
         case 'select':
            mqttClient.publish(sessionId + '/project/ready', topicTokens[1]);
            break;
      
         case 'stop':
            stopProcesses();
            break;

         case 'run':
            runProject(topicTokens[1]);
            break;

         case 'build':
            buildProject(topicTokens[1]);
            break;

         case 'keepAlive':
            receiveKeepAlive();
            break;

         case 'exit':
            stopProcesses();
            if (topicTokens[1] == 'agent') {
               exitAgent();
            }
            break;
               
         default:
            break;
      }
      return;
   }
   switch (topicTokens[2]) {
      case 'get':
         sendFile(topicTokens[1], payload);
         break;
   
      case 'file':
         saveFile(topicTokens[1], topicTokens[3], payload);
         break;
   
      default:
         break;
   }
}

resetGaia();
receiveKeepAlive();
