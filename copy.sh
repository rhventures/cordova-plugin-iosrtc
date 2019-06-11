src="dist/cordova-plugin-iosrtc.js"
dst="/Users/peter/Workspace/flutter/wspace/chating/platforms/ios/platform_www/plugins/cordova-plugin-iosrtc/dist/cordova-plugin-iosrtc.js"
dst2="/Users/peter/Workspace/flutter/wspace/chating/platforms/ios/www/plugins/cordova-plugin-iosrtc/dist/cordova-plugin-iosrtc.js"

cat >$dst <<EOF
cordova.define("cordova-plugin-iosrtc.Plugin", function(require, exports, module) {
EOF

cat $src >> $dst

cat >> $dst <<EOF

});
EOF

cp -f $dst $dst2
