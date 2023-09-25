use crate::{
    environments::get_resolved_environment,
    get_state,
    structs::{Environment, Method, Request},
    tree::{build_script_exec_list, find_node_by_id_mut, NodeMut, ScriptExecOrder},
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, Instant};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Serialize, Deserialize)]
pub struct ReqResponse {
    pub headers: HashMap<String, String>,
    pub status: i32,
    pub body: String,
    pub parsed_url: String,
    pub request_unix_timestamp: u128,
    pub request_rutime_ms: u128,
}

#[derive(Serialize, Deserialize)]
pub struct Datadump {
    pub resolvedEnv: Environment,
    pub globalEnv: Environment,
    pub currentEnv: Environment,
    pub requestEnv: Environment,
    pub request: Option<Request>,
    pub response: Option<ReqResponse>,
}

impl Datadump {
    pub fn resolve(&self) -> Environment {
        let mut env = self.globalEnv.clone();
        env.add(&self.currentEnv);
        env.add(&self.requestEnv);
        return env;
    }
}

#[tauri::command]
pub fn get_js_datadump(id: i64) -> Datadump {
    let cw = &mut get_state().workspaces[get_state().cur_workspace];
    let env = get_resolved_environment();
    let global_env = get_state().workspaces[get_state().cur_workspace]
        .global_environ
        .clone();
    let cur_env = match cw.environments.get(get_state().cur_environment) {
        Some(e) => e.clone(),
        None => Environment::new(),
    };
    let request_env = Environment::new();
    let node = find_node_by_id_mut(&mut cw.root_folder, id);
    let req: Option<Request> = match node {
        Some(node) => match node {
            NodeMut::Request(r) => Some(r.clone()),
            _ => None,
        },
        None => None,
    };

    let data = Datadump {
        resolvedEnv: env,
        globalEnv: global_env,
        currentEnv: cur_env,
        requestEnv: request_env,
        request: req,
        response: None,
    };

    return data;
}

#[tauri::command]
pub fn post_js_datadump(data: Datadump) {
    let cw = &mut get_state().workspaces[get_state().cur_workspace];
    cw.global_environ = data.globalEnv;
    if cw.environments.len() > get_state().cur_environment {
        cw.environments[get_state().cur_environment] = data.currentEnv;
    }
}

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
        stop_collecting: false,
        pre: vec![],
        post: vec![],
    })
}

#[tauri::command]
pub async fn send_request(req: Request, datadump_after_scripts: Datadump) -> ReqResponse {
    let start = SystemTime::now();
    let since_the_epoch = start
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards");

    let ready_env = &datadump_after_scripts.resolve();
    let route = parse_and_fill_template(&req.route, ready_env);
    let url = reqwest::Url::parse(&route.to_string());

    let start_time = Instant::now();

    if url.is_err() {
        return ReqResponse {
            headers: HashMap::new(),
            status: -1,
            body: String::from("Failed to parse url"),
            parsed_url: route,
            request_rutime_ms: start_time.elapsed().as_millis(),
            request_unix_timestamp: since_the_epoch.as_millis(),
        };
    }
    let client = reqwest::Client::new();

    let mut headers = reqwest::header::HeaderMap::new();

    for (k, v) in req.headers.iter() {
        let v_parsed = parse_and_fill_template(v, ready_env);
        let k_parsed = parse_and_fill_template(k, ready_env);

        let header_name_result = reqwest::header::HeaderName::from_bytes(k_parsed.as_bytes());
        let header_value_result = reqwest::header::HeaderValue::from_bytes(v_parsed.as_bytes());

        if header_value_result.is_err() || header_name_result.is_err() {
            return ReqResponse {
                headers: HashMap::new(),
                status: -1,
                body: format!("Header pair {}::{} is invalid", k, v),
                parsed_url: route,
                request_rutime_ms: start_time.elapsed().as_millis(),
                request_unix_timestamp: since_the_epoch.as_millis(),
            };
        }

        let header_name = header_name_result.unwrap();
        let header_value = header_value_result.unwrap();

        headers.insert(header_name, header_value);
    }

    let body = parse_and_fill_template(&req.body, ready_env);

    let resp = match req.method {
        Method::GET => client.get(&route).body(body).headers(headers).send().await,
        Method::POST => client.post(&route).body(body).headers(headers).send().await,
        Method::DELETE => {
            client
                .delete(&route)
                .body(body)
                .headers(headers)
                .send()
                .await
        }
        Method::PATCH => {
            client
                .patch(&route)
                .body(body)
                .headers(headers)
                .send()
                .await
        }
    };

    let mut header_map: HashMap<String, String> = HashMap::new();

    if resp.is_err() {
        return ReqResponse {
            headers: HashMap::new(),
            status: -1,
            body: format!("{:?}", resp),
            parsed_url: route,
            request_rutime_ms: start_time.elapsed().as_millis(),
            request_unix_timestamp: since_the_epoch.as_millis(),
        };
    }

    for (header, content) in resp.as_ref().unwrap().headers().iter() {
        let headerstr = header.to_string();
        let contentstr = content.to_str().unwrap();
        header_map.insert(headerstr, contentstr.to_string());
    }

    let r = ReqResponse {
        status: resp.as_ref().unwrap().status().as_u16() as i32,
        body: resp.unwrap().text().await.unwrap(),
        headers: header_map,
        parsed_url: route,
        request_rutime_ms: start_time.elapsed().as_millis(),
        request_unix_timestamp: since_the_epoch.as_millis(),
    };

    r.into()
}
