const path = require("path")
const webpack = require("webpack")

module.exports = {
    entry: "./static/js/mqtt.js",
    output: {
        filename: "mqtt_bundle.js",
        path: path.resolve(__dirname, "static/dist"),
        clean: true
    },
    mode: "production",
    plugins: [
        new webpack.ProvidePlugin({
            process: "process/browser",
            Buffer: ["buffer", "Buffer"],
        }),
    ],
    resolve: {
        extensions: [".js"],
        fallback: {
            fs: false,
            tls: false,
            "path": require.resolve("path-browserify"),
            "crypto": require.resolve("crypto-browserify"),
            "stream": require.resolve("stream-browserify"),
            "util": require.resolve("util/"),
        }
    },
};