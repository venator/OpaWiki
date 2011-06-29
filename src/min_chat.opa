/** This is a port of demochat v2 to a module */

//package demowiki.min_chat
import stdlib.widgets.{core,button}

type Min_chat.config = {
  user_style_of_kind: Min_chat.mess_kind -> WStyler.styler
  message_style_of_kind: Min_chat.mess_kind -> WStyler.styler
}

type Min_chat.mess_kind = { user } / { system }
type Min_chat.mess = {id: string; message: string; kind: Min_chat.mess_kind}

Min_chat_server = {{
  init() =
    Network.empty():Network.network(Min_chat.mess)
}}

Min_chat_client = {{
  user_update(config) = Session.make_callback(x:Min_chat.mess -> (
    line = <div class="minchat_line">
      <div class="minchat_wrap">
      {<div class="minchat_user">{OpaValue.to_string(x.id)}</div>
        |> WStyler.add(config.user_style_of_kind(x.kind), _)}
      {<div class="minchat_message">{x.message}</div>
        |> WStyler.add(config.message_style_of_kind(x.kind), _)}
      </div>
    </div>
    do Dom.transform([#minchat_show +<- line ])
    Dom.set_scroll_top(#minchat_show, Dom.get_height(#minchat_show) + Dom.get_scroll_top(#minchat_show))
  ))

  load(config, room) = _ -> Network.add(user_update(config), room)
}}

Min_chat = {{
  default_config = {
    user_style_of_kind(kind) = (match kind with
      | {user} -> WStyler.make_style(css {background: #DCE4E7;})
      | {system} -> WStyler.make_style(css {background: #CCFFCC;}))

    message_style_of_kind(kind) = (match kind with
      | {user} -> WStyler.make_style(css {color: black;})
      | {system} -> WStyler.make_style(css {color: #666666;}))
  }

  broadcast(room, id: string, kind: Min_chat.mess_kind, message: string) =
    do Network.broadcast({~id ~message ~kind}, room)
    _ = Dom.set_value(#minchat_entry, "")
    void

  start(config, room, id) =
    broadcast_aux(_) =
      Dom.get_value(#minchat_entry)
        |> broadcast(room, id, {user}, _)
    // HTML chunk of the chat
    <div id="minchat_frame">
      <script onready={Min_chat_client.load(config, room)}/>
      <div id="minchat_show"></div>
      <div id="minchat_controls">
        <input id="minchat_entry"
            onfocus={_ -> _ = Dom.set_value(#minchat_entry, "") void}
            onnewline={broadcast_aux}/>
        <>{WButton.make_default(broadcast_aux, "Send!")}</>
      </div>
    </div>
}}
