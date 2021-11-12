// Imports
const { spawn, exec } = require('child_process');
const AWS = require('aws-sdk');
const AWSIoTData = require('aws-iot-device-sdk');
const fs = require('fs');
const os = require('os');
const util = require('util');

// AWS configurations
var awsConfig = {
   poolId: 'us-west-2:167b474a-b678-4271-8f1e-77f84aa530f7', // 'YourCognitoIdentityPoolId'
   host: 'a31gq30tvzx17m-ats.iot.us-west-2.amazonaws.com', // 'YourAwsIoTEndpoint', e.g. 'prefix.iot.us-east-1.amazonaws.com'
   region: 'us-west-2' // 'YourAwsRegion', e.g. 'us-east-1'
};
AWS.config.region = awsConfig.region;
AWS.config.credentials = new AWS.CognitoIdentityCredentials({
   IdentityPoolId: awsConfig.poolId
});
var cognitoIdentity = new AWS.CognitoIdentity();

// MQTT
var mqttClient;

// Sandbox-specific variables
const numberOfCpus = os.cpus().length;
var coordinatorName = process.env.COORDINATOR_NAME || 'sandbox_coordinator';
var agentId = process.env.AGENT_ID;

// TODO: refactor sandbox to use only SESSION_ID instead of having two redundant environment variables.
var sessionId = process.env.SESSION_ID;
process.env.REMOTE_CLIENT_ID = sessionId;

const sendKeepAliveInterval = 1;  // in minutes
const receiveKeepAliveInterval = 3;  // in minutes

// Agent-specific variables
const projects = {
   'access_control': {
      command: 'source',
      args: ['../start_access_control.sh']
   },
   'amr_swarm': {
      command: '../start_amr_swarm.sh',
      args: []
   }
}

var gaiaDbServer = null;

var activeProject = null;

var makeProcess = null;
var projectProcess = null;
var receiveKeepAliveTimeout;

// This makes exec() friendly for async/await code.
const promiseExec = util.promisify(exec);

// This is useful after calling spawn(), which is more tedious to promisify than exec().
function promisify_child_process(child) {
   return new Promise((resolve, reject) => {
      child.on("error", error => reject(error));
      child.on("close", (code, signal) => {
         if (signal) {
            reject(new Error(`Child process received signal ${signal} and exited with code ${code}.`));
         } else if (code != 0) {
            reject(new Error(`Child process exited with code ${code}.`));
         } else {
            resolve(child);
         }
      });
   })
}

// Connect to the MQTT broker and register callbacks for MQTT-related events.
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

function mqttClientConnectHandler() { 
   console.log('connect, clientId: ' + agentId);

   mqttClient.subscribe(agentId + '/#');
   publishToCoordinator('connected', agentId);
   setTimeout(sendKeepAlive, sendKeepAliveInterval * 60 * 1000);
   if (sessionId == 'standby') {
      console.log('Building project(s)...');
      // TODO: rewrite to use the projects object instead of projectNames
      projectNames.forEach(function(projectName){
         buildProject(projectName);
      });
   } else {
      mqttClient.publish(sessionId + '/session', 'loaded');      
   }
}

function mqttClientReconnectHandler() {
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

async function fileExists(file) {
   try {
      await fs.promises.access(file);
      return true;
   } catch {
      return false;
   }
}

function getBuildDir(projectName) {
   return `/usr/src/app/templates/${projectName}_template/build`;
}

function getDataDir(projectName) {
   return `~/.local/share/gaia/${projectName}/db`;
}

async function purgeGaiaDbData(projectName) {
   stopGaiaDbServer(projectName);
   const dataDirExists = await fileExists(getDataDir(projectName));

   if (dataDirExists) {
      const { stdout, stderr } = await promiseExec(`rm -r ${getDataDir(projectName)}`);
      if (stdout) { console.log(stdout); }
      if (stderr) { console.error(stderr); }
   }
}

async function startGaiaDbServer(projectName, purgeOldData = false) {
   gaiaDbServer = spawn('gaia_db_server', ['--data-dir', getDataDir(projectName)], {
      // Ingore stdin, ignore stdout, ignore stderr
      stdio: ['ignore', 'ignore', 'ignore']
   });
}

// TODO: make this async with an error when the DB server can't be killed.
function stopGaiaDbServer() {
   if (gaiaDbServer) {
      gaiaDbServer.kill();
      gaiaDbServer = null;
   }
}

async function selectProject(projectName) {
   if (!projects.hasOwnProperty(projectName)) {
      throw new Error(`Project ${projectName} doesn't exist`);
   }

   activeProject = null;
   console.log(`Switching to project ${projectName}...`);

   stopGaiaDbServer();
   await purgeGaiaDbData(projectName);
   await startGaiaDbServer(projectName);

   activeProject = projectName;
   console.log(`Selected project ${projectName}.`);
}

async function cleanBuildDirectory(projectName) {
   const buildDir = getBuildDir(projectName);
   const buildDirExists = await fileExists(buildDir);
   var command;

   if (buildDirExists) {
      command = `rm -r ${buildDir} && mkdir -p ${buildDir}`;
   } else {
      command = `mkdir -p ${buildDir}`;
   }

   console.log(`Cleaning build directory of project ${projectName}.`);
   const { stdout, stderr } = await promiseExec(command);
   if (stdout) { console.log(stdout); }
   if (stderr) { console.error(stderr); }
}

async function cmakeConfigure(projectName) {
   console.log(`Configuring CMake for project ${projectName}.`);
   const buildDir = getBuildDir(projectName);

   const cmakeProcess = spawn('cmake', ['..'], {
      cwd: buildDir,
      // Ingore stdin, use Node's stdout, use Node's stderr
      stdio: ['ignore', 'inherit', 'inherit']
   });

   await promisify_child_process(cmakeProcess);
}

function stopProcesses() {
   if (makeProcess) {
      makeProcess.kill();
      makeProcess = null;
      mqttClient.publish(sessionId + '/project/build', 'cancelled');
   }
   if (projectProcess) {
      projectProcess.kill();
      projectProcess = null;
      mqttClient.publish(sessionId + '/project/program', 'stopped');
   }
}

async function makeBuild(projectName) {
   console.log(projectName + ' build started...');
   //publishToEditor('output', 'New build started\n');
   //mqttClient.publish(sessionId + '/project/build', 'building');

   const buildDir = getBuildDir(projectName);
   // Leave one thread available for NodeJS
   const makeThreads = (numberOfCpus > 1) ? (numberOfCpus - 1) : 1;

   makeProcess = spawn('make', [`-j${makeThreads}`], {
      cwd: buildDir,
      // TODO: set stdin to 'ignore' after removing the getline() block from access_control
      // Ingore stdin, pipe the stdout, pipe the stderr
      stdio: ['ignore', 'pipe', 'pipe']
   });

   makeProcess.stdout.on('data', chunk => {
      //publishToEditor('output/append', chunk);
      process.stdout.write(chunk.toString());
   });
   makeProcess.stderr.on('data', chunk => {
      //publishToEditor('output/append', chunk);
      process.stderr.write(chunk.toString());
   });

   try {
      await promisify_child_process(makeProcess);
      //mqttClient.publish(sessionId + '/project/build', 'success');
   } catch {
      if (!makeProcess.killed) {
         //mqttClient.publish(sessionId + '/project/build', 'failed');
      }
   }
   makeProcess = null;
}

function runProject(projectName) {
   const buildDir = getBuildDir(projectName);
   const project = projects[projectName];

   projectProcess = spawn(project.command, project.args, {
      shell: '/bin/bash',
      cwd: buildDir,
      // Inherit Node's stdin, pipe the stdout, pipe the stderr
      stdio: ['inherit', 'pipe', 'pipe']
   });

   //publishToEditor('output/append', 'Running application...\n');
   //mqttClient.publish(sessionId + '/project/program', 'running');

   projectProcess.stdout.on('data', chunk => {
      //publishToEditor('output/append', chunk);
      process.stdout.write(chunk.toString());
   });
   projectProcess.stderr.on('data', chunk => {
      //publishToEditor('output/append', chunk);
      process.stderr.write(chunk.toString());
   });
   
   projectProcess.on('close', code => {
      console.log(`${projectName} exited with code ${code}.`);
      //mqttClient.publish(sessionId + '/project/program', 'stopped');
      projectProcess = null;
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
            selectProject(topicTokens[1]).then(mqttClient.publish(sessionId + '/project/ready', topicTokens[1]));
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
            break;
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

function agentInit() {
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
   
   resetGaia();
   receiveKeepAlive();
}

// TODO: remove this, it's only for testing in a terminal.
process.on('SIGINT', () => {
   console.log("\nCaught interrupt signal.");
   process.exit();
});

// This script is being incrementally tested, so the normal init procedure should not occur.
//agentInit();

async function runTests() {
   const p = 'amr_swarm'
   await selectProject(p);
   await cleanBuildDirectory(p);
   await cmakeConfigure(p);
   await makeBuild(p);
   runProject(p);
}

runTests();