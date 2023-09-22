// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod fs;
mod req;
mod structs;
mod tree;
use fs::save_workspace_to_config;
use req::*;
use structs::*;
use tree::*;

struct AppState {
    workspaces: Vec<Workspace>,
    cur_workspace: usize,
}

static mut STATE: AppState = AppState {
    workspaces: vec![],
    cur_workspace: 0,
};

fn get_state() -> &'static mut AppState {
    unsafe {
        return &mut STATE;
    }
}

fn save_workspace() {
    let ws = &get_state().workspaces[get_state().cur_workspace];
    save_workspace_to_config(&ws.name, ws).unwrap();
}

fn main() {
    let initial_work: Workspace = Workspace {
        id_counter: 1,
        name: "Initial".to_owned(),
        root_folder: structs::Folder {
            id: 1,
            name: "Root".to_owned(),
            pre_request_script: None,
            post_request_script: None,
            requests: vec![],
            sub_folders: vec![],
            disable_parent_scripts: false,
        },
        environments: vec![],
    };

    get_state().workspaces.push(initial_work);

    save_workspace();

    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            create_request,
            get_ui_req_tree,
            create_folder,
            get_current_focus_item,
            save_request,
            send_request,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
