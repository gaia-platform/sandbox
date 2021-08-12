// Imports
var AWS = require('aws-sdk');
var AWSIoTData = require('aws-iot-device-sdk');

console.log('Loaded AWS SDK for JavaScript and AWS IoT SDK for Node.js');


//// Variables
/// MQTT
var awsConfig = {
   poolId: 'us-west-2:167b474a-b678-4271-8f1e-77f84aa530f7', // 'YourCognitoIdentityPoolId'
   host: 'a31gq30tvzx17m-ats.iot.us-west-2.amazonaws.com', // 'YourAwsIoTEndpoint', e.g. 'prefix.iot.us-east-1.amazonaws.com'
   region: 'us-west-2' // 'YourAwsRegion', e.g. 'us-east-1'
};

// Incoming message buffer and state
window.unreadMessages = false;
window.messages = [];

// MQTT State
let subscribedTopics = [];


//// Setup AWS and MQTT
AWS.config.region = awsConfig.region;

AWS.config.credentials = new AWS.CognitoIdentityCredentials({
   IdentityPoolId: awsConfig.poolId
});

/// Config and connect MQTT
const mqttClient = AWSIoTData.device({
   region: AWS.config.region,
   host: awsConfig.host,
   clientId: window.sandboxUuid, // Utilize UUID generated by sandbox website
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
            alert('error retrieving credentials: ' + err);
         }
      });
   } else {
      console.log('error retrieving identity:' + err);
      alert('error retrieving identity: ' + err);
   }
});


//// MQTT functions
function mqttClientConnectHandler() { // Connection handler
   console.log('connect');
}

function mqttClientReconnectHandler() { // Reconnection handler
   console.log("reconnect");
}

function mqttClientMessageHandler(topic, payload) { // Message handler
   console.log('message: ' + topic + ':' + payload.toString());

   // Add message
   let msg = { topic: topic.toString(), payload: payload.toString() }
   window.messages.push(JSON.stringify(msg))

   if (!window.unreadMessages) {
      window.unreadMessages = true;
   }

   window.editorMessageHandler(topic.toString(), payload.toString());
}

// Install handlers
mqttClient.on('connect', mqttClientConnectHandler);
mqttClient.on('reconnect', mqttClientReconnectHandler);
mqttClient.on('message', mqttClientMessageHandler);


//// Methods
// Subscribe to topics
window.subscribeToTopic = function (topic) {
   var fullTopicName = window.sandboxUuid + "/" + topic;
   mqttClient.subscribe(fullTopicName);
   if (topic !== "editor/#") {
      subscribedTopics.push(fullTopicName);
   }
}

// Sending data out
window.publishData = function (topic, payload) { // Topic publish handler
   mqttClient.publish(topic, payload);
}

// Sending data to Godot
window.readNextMessage = function () {
   let nextMessage = window.messages.shift();

   if (window.messages.length === 0) {
      window.unreadMessages = false;
   }

   return nextMessage;
}

// Cleaning up
window.mqttCleanup = function () {
   unsubscribeFromTopics();
}
function unsubscribeFromTopics() {
   subscribedTopics.forEach((topic, index) => mqttClient.unsubscribe(topic));
}
