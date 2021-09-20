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

const keepAliveInterval = 15;  // in minutes

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
   accessKeyId: AWS.config.credentials.accessKeyId,
   secretKey: AWS.config.credentials.secretAccessKey,
   sessionToken: AWS.config.credentials.sessionToken
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

function mqttClientMessageHandler(topic, payload) { // Message handler
   console.log('message: ' + topic);
   console.log('payload: ' + payload);
   var topicTokens = topic.split('/');
   switch (topicTokens[2]) {
      case 'get':
         sendFile(topicTokens[1], payload);
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
