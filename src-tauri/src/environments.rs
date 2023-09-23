use crate::{
    get_state,
    structs::{Environment, EnvironmentType},
    workspaces::save_workspaces,
};

#[tauri::command]
pub async fn get_environment_list() -> Vec<(usize, String)> {
    let ws = &get_state().workspaces[get_state().cur_workspace];
    return ws
        .environments
        .iter()
        .enumerate()
        .map(|(usize, environ)| {
            (
                usize,
                match environ.env_type.clone() {
                    EnvironmentType::Named(name) => name.clone(),
                    _ => String::from(""),
                },
            )
        })
        .collect();
}

#[tauri::command]
pub async fn add_environment() {
    let ws = &mut get_state().workspaces[get_state().cur_workspace];
    let mut new_environ = Environment::new();
    new_environ.env_type = EnvironmentType::Named(String::from("New environment"));
    ws.environments.push(new_environ);
    save_workspaces();
}

#[tauri::command]
pub async fn set_cur_environment(index: i32) {
    if index < 0 {
        return;
    }
    get_state().cur_environment = index as usize;
}

#[tauri::command]
pub async fn save_environment(env: Environment) {
    let ws = &mut get_state().workspaces[get_state().cur_workspace];
    ws.environments[get_state().cur_environment] = env;
}
