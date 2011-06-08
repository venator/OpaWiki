/** This is a module port of Wiki CSS */

//package demowiki.wiki_css

/**
 * This example implements a non-trivial wiki without formatting.
 * It demonstrates some of the database features of OPA, including
 * full-text search, index manipulation, etc.
 *
 * Version: OPA S3
 */

type Wiki_css.config = {
  user: option(string) /** The logged in user (if there is one) */

  on_edit: string -> void /** Called when a page is being edited */
  on_save: string -> void /** Called when a page is saved */
}

/**
 * {1 Database}
 */

/**
 * Customize the database this program will use.
 *
 * Here, we put the database in the file system, in a file called "wiki0"
 */
database ./wiki0/db

/**
 * Define informations that will persist to the database.
 * Here, a page is a [string], indexed by its name, also a [string].
 * When a page doesn't exist, we produce a default page with a default text.
 */
db /wiki : stringmap(string)
db /wiki[_] = "this is a new page"

/**
 * {1 Database interface}
 */

@publish Wiki_css_server = {{
  wiki(name) = /wiki[name] : string

  save_db(name,value) = /wiki[name] <- value

  searchwiki(word) =
    Db.stringmap_search(@/wiki,word)

  get_index() =
     //all = /wiki
     //Map.fold(k, v, acc -> k +> acc
     Map.To.key_list(/wiki)
     //else <div>{ Map.fold( add_item2(config, _, _, _) , all, empty_xml) }</div>
}}


Wiki_css = {{

  default_config: Wiki_css.config = {
    user = none

    on_edit = _ -> void
    on_save = _ -> void
  }

  get_page_title(name: string): string =
     name ^ " | MLstate Wiki Demo"

  /**
   * {1 User interface}
   */

  /**
   * A few constants.
   *
   * If you wish to display icons instead of text, replace these text tags with <img> tags.
   */

  saved    = <h3> Saved </h3>
  loading  = <h3> Loading </h3>
  modified = <h3> Modified </h3>
  original = <h3> Original </h3>

  /**
   * A shared constructor for buttons
   */
  button(id,message,action,parm): xhtml=
      <a id={"wiki_" ^ id:string} onclick={_ -> action(parm)}>
        {message:string}
      </a>

  /**
   * Construct a ui element to display an entry in the wiki.
   *
   * On double-click, this viewer will turn into an editor.
   */
  view(config: Wiki_css.config, name): xhtml =
    Option.switch((_ -> // A user is logged in, enable editing
      <p ondblclick={doEdit(config, name, _)} class="clickable">
        {Wiki_css_server.wiki(name)}
      </p>),
      // If no user given, disable editing
      (<p class="clickable">{Wiki_css_server.wiki(name)}</p>),
      config.user)

  /**
   * Construct a ui element to modify an entry in the wiki.
   * The user may click on two buttons :
   * "save" (to save the entry)
   * "cancel" to cancel editing.
   */
  edit(config: Wiki_css.config, name): xhtml =
    <>
    <textarea onkeyup={onkeyup} rows={10} cols={50} class="wiki_textarea" id="wiki_textarea_content">
      {Wiki_css_server.wiki(name)}
    </textarea>
    <br/>
    {button("save","Save", save(config: Wiki_css.config, _), name)}
    {button("cancel","Cancel", doView(config: Wiki_css.config, _) ,name )}
    </>

  // TODO: factorize with [load_wiki_page]
  goto_page(config: Wiki_css.config) =
    Dom.get_value(#wiki_title_input)
      |> load_wiki_page(config, _)

  edit_title(config: Wiki_css.config, name): xhtml =
      //{button("goto", "Go", goto_page(config: Wiki_css.config, _), name)/* TODO: remove unused argument */ }
      //<a  class="wiki_button" onclick={_ -> goto_page(config) }>Go</a><br/>
    <>
      <input id="wiki_title_input" type="text" value="{name}" />
      <button onclick={_ -> goto_page(config) }>Go</button><br/>
    </>

  /**
   * User interface handlers.
   *
   * Invoked when users click on one of the buttons/fields.
   */
  onkeyup(_event) =
    Dom.transform([ #wiki_result <- modified ])

  doEdit(config: Wiki_css.config, name,_) =
    do config.on_edit(name)
    Dom.transform([ #wiki_area <- edit(config, name) ])

  doEditTitle(config: Wiki_css.config, name, _) =
    Dom.transform([ #wiki_title <- edit_title(config, name) ])

  doView(config: Wiki_css.config, name) =
    Dom.transform([ #wiki_result <- saved, #wiki_area <- view(config, name) ])

  save(config: Wiki_css.config, name) =
     do Dom.transform([  #wiki_result <- loading ]);
     do Wiki_css_server.save_db(name,Dom.get_value(#wiki_textarea_content))
     do config.on_save(name)
     Dom.transform([ #wiki_result <- saved ,
        #wiki_area <- view(config, name) ])

  /**
   * Construct the main user interface.
   *
   * @param name The name of the page (topic).
   */
  page(config: Wiki_css.config, name: string): xhtml =
    <h1 id="wiki_title" ondblclick={doEditTitle(config, name, _)}>{ name:string }</h1>
    <div id="wiki_content">
      <div id="wiki_area">{view(config, name)}</div>
      <>{Option.switch(_ -> <div id="wiki_result">{original}</div>, <></>, config.user)}</>
      <div id="wiki_search_area">
      {search(config)}<br/>
      <a  class="wiki_button" onclick={_ -> Dom.transform([#wiki_preview <- index(config) ]) }>Index</a>
      <div id="wiki_preview"></div>
    </div>
    </div>

  /**
   * {1 Searching through the wiki}
   */

  load_wiki_page(config: Wiki_css.config, name: string) =
    //do evt.stopPropagation()
    do Dom.transform([#wiki_css <- page(config, name)])
    do Client.setTitle(get_page_title(name))
    Client.register_anchor(name, (-> load_wiki_page(config, name)))

  //add_item2(config: Wiki_css.config, k, v, acc) = <>{acc}<li> <a onclick={load_wiki_page_evt(config, k, _)}>{k}</a></li></>
  add_item(config: Wiki_css.config, k, acc) = <>{acc}<li> <a onclick={_ -> load_wiki_page(config, k)}>{k}</a></li></>

  /**
   * Construct and display the user-readable index of all entries
   *
   * This index is a user-readable ui list of hyperlinks to corresponding pages.
   */
  index(config: Wiki_css.config) =
       all = Wiki_css_server.get_index()
       if List.is_empty(all)
       then <div>Empty Index</div>
       else <ul class="wiki_list">{ List.foldl( add_item(config, _, _) , all, empty_xhtml) }</ul>

  /**
   * Construct a component for searching through the wiki
   */

  search(config: Wiki_css.config)=
    do_search_and_display(_) =
         word = Dom.get_value(#wiki_search_string)
         result = Wiki_css_server.searchwiki(word)
         display =
             if List.is_empty( result) then <div> No result </div>
             else <ul class="wiki_list">{ List.foldl( add_item(config, _, _) , result, empty_xhtml) }</ul>
         Dom.transform([#wiki_resultsearch <- display])
         <div><input id="wiki_search_string" class="wiki_input"
             onfocus={_ -> _ = Dom.set_value(#wiki_search_string, "") void} value="search" />
         <a class="wiki_button" onclick={do_search_and_display} href="#">Search</a>
      </div>
      <div id="wiki_resultsearch"></div>

}}
