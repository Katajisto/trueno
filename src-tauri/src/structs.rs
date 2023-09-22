use std::collections::HashMap;

use serde::{Deserialize, Serialize};

pub enum EnvironmentType {
    Global,
    Named(String),
    RequestScoped,
}

pub struct Environment {
    env_type: EnvironmentType,
    key_value: HashMap<String, String>,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct Template {
    pub raw_text: String,
    // ... more
}

impl Template {
    pub fn new() -> Template {
        Template {
            raw_text: String::new(),
        }
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub enum Method {
    GET,
    POST,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct Request {
    pub id: i64,
    pub name: String,
    pub headers: HashMap<String, Template>,
    pub payload: Template,
    pub route: String,
    pub method: Method,
}

impl Request {
    pub fn new(name: &str, id: i64) -> Request {
        Request {
            id,
            name: name.to_string(),
            headers: HashMap::new(),
            payload: Template::new(),
            route: String::from(""),
            method: Method::GET,
        }
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub struct Script {
    code: String,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct Folder {
    pub id: i64,
    pub name: String,
    pub pre_request_script: Option<Script>,
    pub post_request_script: Option<Script>,
    pub requests: Vec<Request>,
    pub sub_folders: Vec<Folder>,
    pub disable_parent_scripts: bool,
}

impl Folder {
    pub fn new(id: i64, name: String) -> Folder {
        Folder {
            id,
            name,
            pre_request_script: None,
            post_request_script: None,
            requests: vec![],
            sub_folders: vec![],
            disable_parent_scripts: false,
        }
    }
}

/// Workspace root. All data must be saved under one of these, since saving data
/// is going to work by serializing these to JSON.
pub struct Workspace {
    /// We get new ids for children from this. Do not modify. Use get_new_id().
    pub id_counter: i64,
    /// Name of workspace, lol
    pub name: String,
    /// All environments that this workspace has.
    pub environments: Vec<Environment>,
    /// The root folder for requests in this workspace.
    pub root_folder: Folder,
}

impl Workspace {
    /// Gets new id for child in request tree. Increments counter and returns a new ID for you.
    pub fn get_new_id(&mut self) -> i64 {
        self.id_counter += 1;
        return self.id_counter;
    }
}
