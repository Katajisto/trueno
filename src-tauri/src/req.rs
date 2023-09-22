use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::structs::Request;

#[derive(Serialize, Deserialize)]
pub struct ReqResponse {
    pub headers: HashMap<String, String>,
    pub status: i32,
    pub body: String,
}

#[tauri::command]
pub async fn send_request(req: Request) -> ReqResponse {
    let resp = reqwest::get(req.route).await.unwrap();

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
