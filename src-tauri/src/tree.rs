use serde::{Deserialize, Serialize};

use crate::structs::{Environment, Folder, Request, Workspace};

use crate::get_state;
use crate::workspaces::{save_workspaces, WorkspaceDTO};

#[derive(Serialize, Deserialize)]
pub struct ReqTreeNode {
    name: String,
    id: i64,
    children: Vec<ReqTreeNode>,
}

pub enum NodeMut<'a> {
    Folder(&'a mut Folder),
    Request(&'a mut Request),
}

pub fn find_node_by_id_mut<'a>(folder: &'a mut Folder, target_id: i64) -> Option<NodeMut<'a>> {
    if folder.id == target_id {
        return Some(NodeMut::Folder(folder));
    }

    for request in &mut folder.requests {
        if request.id == target_id {
            return Some(NodeMut::Request(request));
        }
    }

    for sub_folder in &mut folder.sub_folders {
        if let Some(node) = find_node_by_id_mut(sub_folder, target_id) {
            return Some(node);
        }
    }

    None
}

pub fn find_containing_folder_by_id_mut<'a>(
    folder: &'a mut Folder,
    target_id: i64,
) -> Option<NodeMut<'a>> {
    if folder.id == target_id {
        return Some(NodeMut::Folder(folder));
    }
    // Check each request in the current folder
    if folder
        .requests
        .iter()
        .any(|request| request.id == target_id)
    {
        return Some(NodeMut::Folder(folder));
    }

    // Recursively search in sub-folders
    for sub_folder in &mut folder.sub_folders {
        if let Some(node) = find_containing_folder_by_id_mut(sub_folder, target_id) {
            return Some(node);
        }
    }

    None
}
pub fn get_request_tree(folder: &Folder) -> ReqTreeNode {
    let mut n = ReqTreeNode {
        name: folder.name.clone(),
        id: folder.id,
        children: vec![],
    };
    for req in folder.requests.iter() {
        n.children.push(ReqTreeNode {
            name: req.name.clone(),
            id: req.id,
            children: vec![],
        });
    }

    for subfolder in folder.sub_folders.iter() {
        let new_node = get_request_tree(subfolder);
        n.children.push(new_node);
    }

    return n;
}

#[tauri::command]
pub fn get_ui_req_tree() -> ReqTreeNode {
    let state = get_state();
    let workspace_i = state.cur_workspace;
    println!("Creating tree for workspace with index: {}", workspace_i);
    return get_request_tree(&state.workspaces[workspace_i].root_folder).into();
}

#[derive(Serialize, Deserialize)]
pub enum FocusItem {
    Folder(Folder),
    Request(Request),
    Workspace(WorkspaceDTO),
    Environment(Environment),
    None,
}

/// Gets the current focus item based on ID.
/// ID has a few special cases. If ID is -1, it means the current workspace.
/// If ID is -2, it means the current environment.
/// In those cases we return the environment or the workspace.
#[tauri::command]
pub fn get_current_focus_item(cur_id: i64) -> FocusItem {
    // We have a few special cases for the ID for the sake of this being easy to implement.
    if cur_id == -1 {
        let cur_ws = &get_state().workspaces[get_state().cur_workspace];
        return FocusItem::Workspace(WorkspaceDTO::from_workspace(cur_ws));
    }

    if cur_id == -2 {
        let cur_ws = &get_state().workspaces[get_state().cur_workspace];

        if cur_ws.environments.len() == 0
            || get_state().cur_environment > cur_ws.environments.len() - 1
        {
            return FocusItem::None;
        }
        return FocusItem::Environment(cur_ws.environments[get_state().cur_environment].clone());
    }

    let node = find_node_by_id_mut(
        &mut get_state().workspaces[get_state().cur_workspace].root_folder,
        cur_id,
    );

    if node.is_none() {
        return FocusItem::None;
    }

    match node.unwrap() {
        NodeMut::Folder(f) => FocusItem::Folder(f.clone()).into(),
        NodeMut::Request(r) => FocusItem::Request(r.clone()).into(),
    }
}

#[tauri::command]
pub fn create_request(name: &str, cur_id: i64) -> ReqTreeNode {
    let node = find_containing_folder_by_id_mut(
        &mut get_state().workspaces[get_state().cur_workspace].root_folder,
        cur_id,
    );

    match node {
        Some(val) => match val {
            NodeMut::Folder(f) => {
                f.requests.push(Request::new(
                    name,
                    get_state().workspaces[get_state().cur_workspace].get_new_id(),
                ));
            }
            NodeMut::Request(r) => {} // we are looking for the containing folder so we wont ever hit this.
        },
        None => (),
    }

    get_ui_req_tree().into()
}

#[tauri::command]
pub fn save_request(req: Request) -> ReqTreeNode {
    let node = find_node_by_id_mut(
        &mut get_state().workspaces[get_state().cur_workspace].root_folder,
        req.id,
    );

    if node.is_none() {
        return get_ui_req_tree().into();
    }

    match node.unwrap() {
        NodeMut::Request(r) => {
            r.name = req.name;
            r.headers = req.headers;
            r.payload = req.payload;
            r.route = req.route;
            r.method = req.method;
        }
        _ => (),
    }

    save_workspaces();

    return get_ui_req_tree().into();
}

#[tauri::command]
pub fn create_folder(name: &str, cur_id: i64) -> ReqTreeNode {
    let node = find_containing_folder_by_id_mut(
        &mut get_state().workspaces[get_state().cur_workspace].root_folder,
        cur_id,
    );

    match node {
        Some(val) => match val {
            NodeMut::Folder(f) => {
                f.sub_folders.push(Folder::new(
                    get_state().workspaces[get_state().cur_workspace].get_new_id(),
                    name.to_string(),
                ));
            }
            NodeMut::Request(r) => {}
        },
        None => (),
    }

    get_ui_req_tree().into()
}
