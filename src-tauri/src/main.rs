// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod environments;
mod fs;
#[rustfmt::skip]
mod js;
mod fuzzy;
mod import;
mod req;
mod structs;
mod tree;
mod workspaces;

use req::*;
use structs::*;
use tree::*;
use workspaces::init_workspaces;

use crate::{
    environments::{
        add_environment, delete_current_env, get_environment_list, save_environment,
        set_cur_environment,
    },
    import::add_imported_tree,
    workspaces::{get_workspace_list, new_workspace, save_workspace, set_cur_workspace},
};

/// Global app state struct.
struct AppState {
    workspaces: Vec<Workspace>,
    cur_workspace: usize,
    cur_environment: usize,
}

impl AppState {
    pub fn get_workspace(&mut self) -> &mut Workspace {
        let cur_workspace_id = self.cur_workspace;
        let res = self.workspaces.get_mut(cur_workspace_id);
        return match res {
            Some(ws_ref) => ws_ref,
            None => panic!("Getting the current workspace failed! Please file a bug report with info about this."),
        };
    }
}

// Yes, this is a global variable.
// Yes, this is a risk in async and multithreaded code.
// Yes, you can modify this and cause unintended side effects.
// No, I don't care.
static mut STATE: AppState = AppState {
    workspaces: vec![],
    cur_workspace: 0,
    cur_environment: 0,
};

/// Gets a static mutable pointer to the App state.
/// Be careful when modifying stuff in async functions.
fn get_state() -> &'static mut AppState {
    unsafe {
        return &mut STATE;
    }
}

fn main() {
    init_workspaces();

    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            create_request,
            get_ui_req_tree,
            create_folder,
            get_current_focus_item,
            save_request,
            send_request,
            get_workspace_list,
            set_cur_workspace,
            save_workspace,
            new_workspace,
            add_environment,
            get_environment_list,
            set_cur_environment,
            save_environment,
            save_folder,
            get_pre_and_post_scripts,
            get_js_datadump,
            post_js_datadump,
            get_fuzzy_results,
            delete_current_env,
            delete_request,
            delete_folder,
            get_req_tree_summary,
            add_imported_tree,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
