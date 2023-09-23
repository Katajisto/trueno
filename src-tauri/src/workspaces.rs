use serde::{Deserialize, Serialize};

use crate::{
    fs::{load_workspaces_from_config, save_workspace_to_config},
    get_state,
    structs::{self, Environment, Folder, Workspace},
};

pub fn save_workspaces() {
    for (i, ws) in get_state().workspaces.iter().enumerate() {
        save_workspace_to_config(format!("workspace_{}.json", i).as_str(), ws).unwrap();
    }
}

pub fn init_workspaces() {
    let workspaces = load_workspaces_from_config();

    if workspaces.is_err() {
        let initial_work: Workspace = Workspace {
            id_counter: 1,
            name: "Initial".to_owned(),
            global_environ: Environment::new(),
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
        save_workspaces();
    } else {
        let workspaces_val = workspaces.unwrap();
        get_state().workspaces = workspaces_val;
    }
}

/// Returns a list of workspaces. The string references will be valid as
/// long as the list is valid, since the strings are pointing to workspaces
/// names.
#[tauri::command]
pub fn get_workspace_list() -> Vec<(usize, &'static String)> {
    get_state()
        .workspaces
        .iter()
        .enumerate()
        .map(|(i, ws)| (i, &ws.name))
        .collect()
}
/// Sets the current workspace in state.
#[tauri::command]
pub fn set_cur_workspace(num: i64) {
    if get_state().workspaces.len() == 0 {
        println!("tried to set workspace, but the workspace vec was empty");
        return;
    }
    if num < 0 || num as usize > get_state().workspaces.len() - 1 {
        println!("tried to set workspace index larger than workspace array");
        return;
    }
    get_state().cur_workspace = num as usize;
}

#[tauri::command]
pub fn save_workspace(workspace_dto: WorkspaceDTO) {
    let ws_ref = &mut get_state().workspaces[get_state().cur_workspace];
    ws_ref.name = workspace_dto.name;
    ws_ref.global_environ = workspace_dto.global_environ;
    save_workspaces();
}

#[tauri::command]
pub fn new_workspace() {
    let new_ws = Workspace {
        id_counter: 1,
        name: String::from("New workspace"),
        environments: vec![],
        global_environ: Environment::new(),
        root_folder: Folder::new(1, "Root".to_string()),
    };

    get_state().workspaces.push(new_ws);
    save_workspaces();
}

/// A special struct that contains workspace info the UI needs.
#[derive(Serialize, Deserialize)]
pub struct WorkspaceDTO {
    name: String,
    global_environ: Environment,
}

impl WorkspaceDTO {
    pub fn from_workspace(ws: &Workspace) -> WorkspaceDTO {
        WorkspaceDTO {
            name: ws.name.clone(),
            global_environ: ws.global_environ.clone(),
        }
    }
}
