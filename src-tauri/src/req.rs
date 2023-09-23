use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use tauri::{window, Wry};

use crate::{
    environments::get_resolved_environment,
    structs::{Environment, Request},
    tree::{build_script_exec_list, ScriptExecOrder},
};

#[derive(Serialize, Deserialize)]
pub struct ReqResponse {
    pub headers: HashMap<String, String>,
    pub status: i32,
    pub body: String,
}

#[derive(Serialize, Deserialize)]
pub struct Datadump {
    pub resolvedEnv: Environment,
    pub globalEnv: Environment,
    pub currentEnv: Environment,
    pub requestEnv: Environment,
    pub request: Request,
    pub response: Option<ReqResponse>,
}

pub fn get_js_datadump(req: i64) -> Datadump {}

fn parse_and_fill_template(template: &String, resolved_env: &Environment) -> String {
    let mut output = String::new();
    let mut temp = String::new();
    let mut inside_brackets = false;
    let mut escape_used = false;

    for c in template.chars() {
        if !inside_brackets {
            if !escape_used && c == '{' {
                inside_brackets = true;
                continue;
            }
            if c == '!' {
                escape_used = true;
            } else {
                escape_used = false;
            }
            output.push(c);
        } else {
            if c == '}' {
                inside_brackets = false;
                // Okay we haz our env key now. Rezolv it!
                output.push_str(&resolved_env.get(&temp));
                temp = String::new();
            } else {
                temp.push(c);
            }
        }
    }
    return output;
}

#[tauri::command]
pub fn get_pre_and_post_scripts(req: i64) -> ScriptExecOrder {
    build_script_exec_list(req).unwrap_or(ScriptExecOrder {
        pre: vec![],
        post: vec![],
    })
}

#[tauri::command]
pub async fn send_request(req: Request) -> ReqResponse {
    let env = get_resolved_environment();
    let route = parse_and_fill_template(&req.route, &env);
    let resp = reqwest::get(route).await.unwrap();

    let mut header_map: HashMap<String, String> = HashMap::new();

    for (header, content) in resp.headers().iter() {
        let headerstr = header.to_string();
        let contentstr = content.to_str().unwrap();
        header_map.insert(headerstr, contentstr.to_string());
    }

    let r = ReqResponse {
        status: resp.status().as_u16() as i32,
        body: resp.text().await.unwrap(),
        headers: header_map,
    };

    r.into()
}
