return{
    ---@type boolean
    ae2mode = false,
    ---@type "down"|"up"|"north"|"south"|"west"|"east"
    fromside = "west",
    ---@type "down"|"up"|"north"|"south"|"west"|"east"
    toside = "up",
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
}