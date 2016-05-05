/**
 * Created by renfei on 16/5/5.
 */
var url = ""
function play(file) {

    var reader = new FileReader();
    reader.onload = function () {
        url = reader.result;
    };
    reader.readAsDataURL(file);


}
//初始化
RongIMLib.RongIMVoice.init();

$("#playId").click(function() {
    console.log("vvv")
    RongIMLib.RongIMVoice.play(url);
});

$("#stopId").click(function() {
    console.log("vvv")
    RongIMLib.RongIMVoice.stop();
});
