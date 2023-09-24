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

/// Combines the global env with the currently selected
/// named environment and returns a pre-resolved environment
/// for you.
pub fn get_resolved_environment() -> Environment {
    let mut env = get_state().workspaces[get_state().cur_workspace]
        .global_environ
        .clone();
    let named_env = &get_state().workspaces[get_state().cur_workspace]
        .environments
        .get(get_state().cur_environment);
    match named_env {
        Some(named_env) => {
            for (k, v) in named_env.key_value.iter() {
                env.key_value.insert(k.to_string(), v.to_string());
            }
        }
        None => (),
    };
    return env;
}

impl Environment {
    pub fn add(&mut self, env: &Environment) {
        for (k, v) in env.key_value.iter() {
            self.key_value.insert(k.clone(), v.clone());
        }
    }

    pub fn get_name(&self) -> String {
        match self.env_type.clone() {
            EnvironmentType::Global => String::from("Global"),
            EnvironmentType::Named(n) => n.clone(),
            EnvironmentType::RequestScoped => String::from("Request scoped"),
        }
    }
}

#[tauri::command]
pub fn delete_current_env() {
    let ws = &mut get_state().workspaces[get_state().cur_workspace];
    ws.environments.remove(get_state().cur_environment);
}
