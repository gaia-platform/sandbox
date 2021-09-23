// Imports
const { spawn, exec } = require('child_process');
const AWS = require('aws-sdk');
const AWSIoTData = require('aws-iot-device-sdk');
const fs = require('fs')

console.log('Loaded AWS SDK for JavaScript and AWS IoT SDK for Node.js');

//// Variables
/// MQTT
var awsConfig = {
   poolId: 'us-west-2:167b474a-b678-4271-8f1e-77f84aa530f7', // 'YourCognitoIdentityPoolId'
   host: 'a31gq30tvzx17m-ats.iot.us-west-2.amazonaws.com', // 'YourAwsIoTEndpoint', e.g. 'prefix.iot.us-east-1.amazonaws.com'
   region: 'us-west-2' // 'YourAwsRegion', e.g. 'us-east-1'
};
var agentId = process.env.AGENT_ID;
var sessionId = process.env.SESSION_ID;
process.env.REMOTE_CLIENT_ID = sessionId;

const keepAliveInterval = 15;  // in minutes
//const projectNames = ['access_control', 'amr_swarm'];
const projectNames = ['amr_swarm'];
var gaiaChild = null;

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

function publishToEditor(file, contents) {
   console.log('publish to:' + sessionId + "/editor/" + file);
   mqttClient.publish(sessionId + "/editor/" + file, contents);
}

function publishToCoordinator(action, payload) {
   mqttClient.publish("sandbox_coordinator/" + agentId + "/agent/" + action, payload);
}

function sendKeepAlive() {
   publishToCoordinator('connected', agentId);
   setTimeout(sendKeepAlive, keepAliveInterval * 60 * 1000);
}

//// MQTT functions
function mqttClientConnectHandler() { // Connection handler
   console.log('connect, clientId: ' + agentId);

   //
   // Subscribe to our current topic.
   //
   mqttClient.subscribe(agentId + '/#');
   sendKeepAlive();
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

function cleanProjects() {
   projectNames.forEach(projectName => {
      console.log('rm -r templates/' + projectName + '_template/build/gaia_generated');
      exec('rm -r templates/' + projectName + '_template/build/gaia_generated');
   });
}

function resetGaia(cb) {
   cleanProjects();
   if (gaiaChild) {
      gaiaChild.kill();
      gaiaChild = null;
   }
   exec('rm -r ~/.local/gaia/db/', (error, stdout, stderr) => {
      console.error(`error: ${error}`);
      console.log(`stdout: ${stdout}`);
      console.error(`stderr: ${stderr}`);
      gaiaChild = spawn('gaia_db_server', ['--data-dir', '~/.local/gaia/db']);
      cb();
      gaiaChild.stdout.on('data', (chunk) => {
         console.log(chunk);
      });
      gaiaChild.stdout.on('error', (error) => {
         console.log(error);
      });
      gaiaChild.on('close', (code) => {
         console.log(`child process exited with code ${code}`);
      });
   });
}

function runProject(projectName) {
   var projectProcess = exec('bash ../start_amr_swarm.sh', { cwd: 'templates/' + projectName + '_template/build' });
   publishToEditor('output/append', 'Running application...\n');
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
   });
}

function buildProject(projectName) {
   resetGaia(function () {
      var cmakeBuild = spawn('cmake', ['..'], { cwd: 'templates/' + projectName + '_template/build' });
      cmakeBuild.stdout.on('data', (chunk) => {
         console.log(chunk.toString());
      });
      cmakeBuild.stdout.on('error', (error) => {
         console.log(error);
      });
      cmakeBuild.on('close', (code) => {
         console.log(`child process exited with code ${code}`);
         if (code == 0) {
            publishToEditor('output', 'New build started\n');
            var makeBuild = spawn('make', { cwd: 'templates/' + projectName + '_template/build' });
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
               if (code == 0) {
                  runProject(projectName);
               }
            });
         }
      });
   });
}

function mqttClientMessageHandler(topic, payload) { // Message handler
   console.log('message: ' + topic);
   console.log('payload: ' + payload);
   var topicTokens = topic.split('/');
   switch (topicTokens[2]) {
      case 'get':
         sendFile(topicTokens[1], payload);
         break;

      case 'build':
         buildProject(topicTokens[1]);
         break;
   
      case 'exit':
         process.exit(0);
         break;
         
      default:
         break;
   }
}
