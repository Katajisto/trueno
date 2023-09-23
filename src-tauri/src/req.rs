use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::{
    environments::get_resolved_environment,
    get_state,
    structs::{Environment, Request},
};

#[derive(Serialize, Deserialize)]
pub struct ReqResponse {
    pub headers: HashMap<String, String>,
    pub status: i32,
    pub body: String,
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
