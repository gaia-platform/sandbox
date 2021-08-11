// Imports
var AWS = require('aws-sdk');
var AWSIoTData = require('aws-iot-device-sdk');

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

//// Setup AWS and MQTT
AWS.config.region = awsConfig.region;

AWS.config.credentials = new AWS.CognitoIdentityCredentials({
   IdentityPoolId: awsConfig.poolId
});

/// Config and connect MQTT
const mqttClient = AWSIoTData.device({
   region: AWS.config.region,
   host: awsConfig.host,
   clientId: agentId,
   protocol: 'wss',
   maximumReconnectTimeMs: 8000,
   debug: true,
   accessKeyId: '',
   secretKey: '',
   sessionToken: ''
});

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
            mqttClient.updateWebSocketCredentials(data.Credentials.AccessKeyId,
               data.Credentials.SecretKey,
               data.Credentials.SessionToken);
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

//// MQTT functions
function mqttClientConnectHandler() { // Connection handler
   console.log('connect, clientId: ' + agentId);

   //
   // Subscribe to our current topic.
   //
   mqttClient.subscribe(agentId + '/#');
   publishToCoordinator('connect', agentId);
}

function mqttClientReconnectHandler() { // Reconnection handler
   console.log("reconnect");
}

function sendFiles(projectName) {
   switch (projectName) {
      case 'access_control_template':
         fs.readFile('templates/' + projectName + '/src/access_control.ruleset', 'utf8' , (err, data) => {
            if (err) {
              console.error(err);
              return;
            }
            publishToEditor('ruleset', data);
         });
         fs.readFile('templates/' + projectName + '/src/access_control.ddl', 'utf8' , (err, data) => {
            if (err) {
              console.error(err);
              return;
            }
            publishToEditor('ddl', data);
         });

      break;

      default:
         break;
   }
}

function mqttClientMessageHandler(topic, payload) { // Message handler
   console.log('message: ' + topic);
   console.log('payload: ' + payload);
   var topicTokens = topic.split('/');
   switch (topicTokens[2]) {
      case 'get':
         sendFiles(topicTokens[1]);
         break;

      default:
         break;
   }
}

// Install handlers
mqttClient.on('connect', mqttClientConnectHandler);
mqttClient.on('reconnect', mqttClientReconnectHandler);
mqttClient.on('message', mqttClientMessageHandler);


//// Methods
//window.publishData = function (topic, payload) { // Topic publish handler
//   mqttClient.publish(topic, payload);
//}