return{
    ---@type boolean|nil
    ae2mode = nil,
    ---@type direction
    transposer_fromside = "down",
    ---@type direction
    transposer_toside = "west",
    ---@type direction
    transposer_lookside = "south",
    --mode : `none`,`note`,`chat`,`alarm`,`beep`,`nil` <br>
    --`none` : 何もしない <br>
    --`note` : note block(音ブロック)で通知 <br>
    --`chat` : chatboxで通知 <br>
    --`alarm` : alarmで通知 <br>
    --`beep` : beep音で通知 <br>
    --`nil` : 自動で検知
    ---@type "none"|"note"|"chat"|"alarm"|"beep"|nil
    alarm = nil,
    ---@type "en"|"ja"
    lang = "ja",
    ---@type direction
    mainexportbus_side = "up",
    ---@type integer
    mainexportbus_acceleration = 3,
    ---@type direction
    subexportbus_side = "north",
    ---@type integer
    subexportbus_acceleration = 3,
}