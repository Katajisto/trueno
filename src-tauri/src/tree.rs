use serde::{Deserialize, Serialize};

use crate::fuzzy::score_match;
use crate::js::insert_in_js_harness;
use crate::structs::{Environment, Folder, Request};

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

pub fn find_parent_mut<'a>(folder: &'a mut Folder, target_id: i64) -> Option<NodeMut<'a>> {
    // Check each request in the current folder
    if folder
        .requests
        .iter()
        .any(|request| request.id == target_id)
    {
        return Some(NodeMut::Folder(folder));
    }

    for sub_folder in &mut folder.sub_folders {
        if sub_folder.id == target_id {
            return Some(NodeMut::Folder(folder));
        }
    }

    // Recursively search in sub-folders
    {
        for sub_folder in &mut folder.sub_folders {
            if let Some(node) = find_containing_folder_by_id_mut(sub_folder, target_id) {
                return Some(node);
            }
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
        NodeMut::Folder(f) => {
            let mut folder = f.clone();
            // we don't want to send this stuff to the frontend
            folder.requests = vec![];
            folder.sub_folders = vec![];
            FocusItem::Folder(folder).into()
        }
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

    save_workspaces();
    get_ui_req_tree().into()
}

#[tauri::command]
pub fn delete_request(id: i64) -> ReqTreeNode {
    let folder = find_containing_folder_by_id_mut(
        &mut get_state().workspaces[get_state().cur_workspace].root_folder,
        id,
    );
    match folder {
        Some(n) => match n {
            NodeMut::Folder(f) => {
                let index = f.requests.iter().position(|r| r.id == id).unwrap();
                f.requests.remove(index);
            }
            _ => (),
        },
        None => (),
    };

    save_workspaces();
    return get_ui_req_tree().into();
}

#[tauri::command]
pub fn delete_folder(id: i64) -> ReqTreeNode {
    let folder = find_parent_mut(
        &mut get_state().workspaces[get_state().cur_workspace].root_folder,
        id,
    );
    match folder {
        Some(n) => match n {
            NodeMut::Folder(f) => {
                let index = f.sub_folders.iter().position(|r| r.id == id).unwrap();
                f.sub_folders.remove(index);
            }
            _ => (),
        },
        None => (),
    };

    save_workspaces();
    return get_ui_req_tree().into();
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
            r.route = req.route;
            r.method = req.method;
            r.body = req.body;
            r.pre_script = req.pre_script;
            r.post_script = req.post_script;
        }
        _ => (),
    }

    save_workspaces();

    return get_ui_req_tree().into();
}

#[tauri::command]
pub fn save_folder(folder: Folder) -> ReqTreeNode {
    let node = find_node_by_id_mut(
        &mut get_state().workspaces[get_state().cur_workspace].root_folder,
        folder.id,
    );

    if node.is_none() {
        return get_ui_req_tree().into();
    }

    match node.unwrap() {
        NodeMut::Folder(f) => {
            f.name = folder.name;
            f.pre_request_script = folder.pre_request_script;
            f.post_request_script = folder.post_request_script;
            f.disable_parent_scripts = folder.disable_parent_scripts;
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
    save_workspaces();
    get_ui_req_tree().into()
}

#[derive(Serialize, Deserialize)]
pub struct ScriptExecOrder {
    pub pre: Vec<String>,
    pub post: Vec<String>,
    #[serde(skip_serializing)]
    pub stop_collecting: bool,
}

fn recursively_get_scripts(folder: &Folder, req_id: i64) -> Option<ScriptExecOrder> {
    // Check if folder has the req we are looking for.
    for req in folder.requests.iter() {
        if req.id == req_id {
            // This is the correct folder! Return this folders scripts
            return Some(ScriptExecOrder {
                stop_collecting: folder.disable_parent_scripts,
                pre: vec![
                    insert_in_js_harness(folder.pre_request_script.clone()),
                    insert_in_js_harness(req.pre_script.clone()),
                ],
                post: vec![
                    insert_in_js_harness(folder.post_request_script.clone()),
                    insert_in_js_harness(req.post_script.clone()),
                ],
            });
        }
    }

    // Okay, so this was not the folder with the request...
    // try the subfolders:
    for subfolder in folder.sub_folders.iter() {
        let mut res = recursively_get_scripts(subfolder, req_id);
        if res.is_some() {
            let resp = res.as_mut().unwrap();
            if !resp.stop_collecting {
                resp.pre
                    .push(insert_in_js_harness(folder.pre_request_script.clone()));
                resp.post
                    .push(insert_in_js_harness(folder.post_request_script.clone()));
            }
            if folder.disable_parent_scripts {
                resp.stop_collecting = true;
            }
            return res;
        }
    }

    return None;
}

#[derive(Clone, Serialize, Deserialize)]
pub enum FuzzyResultType {
    Folder,
    Request,
    Settings,
    Workspace,
    Environment,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct FuzzyResult {
    pub id: i64,
    pub name: String,
    pub result_type: FuzzyResultType,
    pub distance: i32,
}

fn recursively_do_fuzzy_find(folder: &Folder, search_str: &String) -> Vec<FuzzyResult> {
    let mut search_res = vec![];
    search_res.push(FuzzyResult {
        id: folder.id,
        name: folder.name.clone(),
        result_type: FuzzyResultType::Folder,
        distance: score_match(&folder.name, search_str),
    });

    // Check if folder has the req we are looking for.
    for req in folder.requests.iter() {
        search_res.push(FuzzyResult {
            id: req.id,
            name: req.name.clone(),
            result_type: FuzzyResultType::Request,
            distance: score_match(&req.name, search_str),
        })
    }

    // Okay, so this was not the folder with the request...
    // try the subfolders:
    for folder in folder.sub_folders.iter() {
        let res = recursively_do_fuzzy_find(folder, search_str);
        for result in res.iter() {
            search_res.push(result.clone());
        }
    }

    return search_res;
}

pub fn build_script_exec_list(req_id: i64) -> Option<ScriptExecOrder> {
    let tree = &get_state().workspaces[get_state().cur_workspace].root_folder;
    let mut list = recursively_get_scripts(tree, req_id);
    if list.is_some() {
        list.as_mut().unwrap().pre.reverse();
    }
    return list;
}

fn recursively_get_tree_summary(folder: &Folder, req_id: i64) -> Option<Vec<String>> {
    if folder.id == req_id {
        return Some(vec![folder.name.clone()]);
    }

    // Check if folder has the req we are looking for.
    for req in folder.requests.iter() {
        if req.id == req_id {
            return Some(vec![req.name.clone()]);
        }
    }

    // Okay, so this was not the folder with the request...
    // try the subfolders:
    for subfolder in folder.sub_folders.iter() {
        let res = recursively_get_tree_summary(subfolder, req_id);
        match res {
            Some(v) => {
                let mut vc = v.clone();
                vc.push(subfolder.name.clone());
                return Some(vc);
            }
            None => (),
        }
    }

    return None;
}
#[tauri::command]
pub fn get_req_tree_summary(id: i64) -> Vec<String> {
    let cur_ws = &get_state().workspaces[get_state().cur_workspace];
    if id == -1 {
        return vec![String::from("Workspace settings")];
    }
    if id == -2 {
        return vec![String::from("Environment settings")];
    }

    let mut list = recursively_get_tree_summary(&cur_ws.root_folder, id);
    if list.is_some() {
        list.as_mut().unwrap().reverse();
    }
    return list.unwrap_or(vec![String::from("")]);
}

#[tauri::command]
pub fn get_fuzzy_results(query: String) -> Vec<FuzzyResult> {
    let cur_ws = &get_state().workspaces[get_state().cur_workspace];
    // Get node results from the tree.
    let mut results = recursively_do_fuzzy_find(&cur_ws.root_folder, &query);

    // Add workspaces to results:
    get_state()
        .workspaces
        .iter()
        .enumerate()
        .map(|(i, ws)| FuzzyResult {
            id: i as i64,
            name: ws.name.clone(),
            distance: score_match(&ws.name, &query),
            result_type: FuzzyResultType::Workspace,
        })
        .for_each(|f| results.push(f));

    cur_ws
        .environments
        .iter()
        .enumerate()
        .map(|(i, env)| FuzzyResult {
            id: i as i64,
            name: env.get_name().clone(),
            distance: score_match(&env.get_name(), &query),
            result_type: FuzzyResultType::Environment,
        })
        .for_each(|f| results.push(f));

    // Manually push some results also.
    results.push(FuzzyResult {
        id: -1,
        name: String::from("Workspace edit"),
        result_type: FuzzyResultType::Settings,
        distance: score_match("workspace edit", &query),
    });
    results.push(FuzzyResult {
        id: -2,
        name: String::from("Environment edit"),
        result_type: FuzzyResultType::Settings,
        distance: score_match("environment edit", &query),
    });

    results.sort_by_key(|res| res.distance);
    results
        .iter()
        .rev()
        .take(5)
        .map(|res| res.clone())
        .collect()
}
