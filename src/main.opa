/*  An application implementing a simple wiki with changes broadcasted on an
 *  embedded chat.
 *
 *  Copyright (C) 2011  MLstate
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Affero General Public License as
 *  published by the Free Software Foundation, either version 3 of the
 *  License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Affero General Public License for more details.
 *
 *  You should have received a copy of the GNU Affero General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 *  An application implementing a simple wiki with changes broadcasted on an
 *  embedded chat.
 *
 *  @author Guillem Rieu <guillem.rieu@mlstate.com>
 */

// TODO: update the code with new components (CChat, CLogin...)
// TODO: refactoring and cleaning
// TODO: properly document the code
// TODO: server-side checking of the right to edit a page

import components.applicationframe

/**
 * Static users for demo purpose. A real-life usage would be to use a DB for
 * storing user information.
 */
@server default_users: list((string, string)) = [
  ("demo", "demo"),
  ("opawiki", "opawiki"),
]

/**
 * Check if a pair (user, password) exists in an association list.
 */
@server check_user(user_list: list((string, string)),
    username: string, password: string) : option(string) =
  if List.exists((usr, pwd) ->
      username == usr && password == pwd, user_list) then
    none // The pair (user, password) exists
  else
    some(" Wrong username/password pair! ")

/**
 * Initialize the login application skeleton
 */
login_app_init:
    (UserContext.t(option((channel(CApplicationFrame.client_message('a)), string))),
    channel(CApplicationFrame.server_message(string))) =
  CApplicationFrame.init(app_config: CApplicationFrame.config(string, void))

/**
 * Initialize the chat room
 */
chat_room = Min_chat_server.init()

/**
 * Broadcast a message to Min_chat when a page is being edited
 */
broadcast_edit(username: string, page_name: string, action: string): void =
  now_str = Date.to_string(Date.now())
  Min_chat.broadcast(chat_room, username, {system},
      "{action} the page '{page_name}' on {now_str}")

get_wiki_config(username: string): Wiki_css.config =
  {
    user=some(username)

    on_edit=broadcast_edit(username, _, "has started editing")
    on_save=broadcast_edit(username, _, "saved")
  }

minchat_config: Min_chat.config = Min_chat.default_config

/**
 * XHTML pages
 */
common_page(wiki_config, page_title: string): xhtml =
  <div id="wiki_css"
      onready={_ -> Wiki_css.load_wiki_page(wiki_config, page_title)}>
  </div>

@server private_page(page_title: string, usr_name: string) =
  wiki_config = get_wiki_config(usr_name)
  <>
    <div id="minchat">
      {Min_chat.start(minchat_config, chat_room, usr_name)}
    </div>
    {common_page(wiki_config, page_title)}
  </>

public_page(page_title: string) =
  <><div id="minchat"></div>
    {common_page(Wiki_css.default_config, page_title)}
  </>

/**
 * Update the chat and the wiki views on logon
 */
client_login_chat(username: string): void =
  Min_chat.broadcast(chat_room, username, {system}, "has logged in")

/**
 * Update the chat and the wiki views on logout
 */
client_logout_chat(username: string, _): void =
  Min_chat.broadcast(chat_room, username, {system}, "has logged out")

/**
 * Configure the application skeleton
 */
app_config: CApplicationFrame.config(string, void) = {CApplicationFrame.default_config with
  authenticate = check_user(default_users, _, _)

  ~public_page
  ~private_page

  on_logout_client(user: string, state: void): void =
    do client_logout_chat(user, state)
    CApplicationFrame.default_config.on_logout_client(user, state)
}

/**
 * Static resources
 */
resources = Rule.of_map(@static_include_directory("resources"))

/**
 * URL parser
 */
urls = parser
  | "/" rsc = resources -> Server.public(_ -> rsc)
  | "/" title_opt=(.+)? ->
    page_title = (match title_opt with
      | {none} -> "Home"
      | {~some} -> Text.to_string(some))
    do Resource.register_external_css("resources/style.css")
    CApplicationFrame.make(login_app_init, app_config, page_title)

/** Server creation (main entry point) */
server =
  {
    Server.secure(Server.ssl_default_params, urls) with
    encryption = {no_encryption}
    port       = 8080
  }
