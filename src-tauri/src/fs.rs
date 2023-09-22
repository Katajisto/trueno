use dirs;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;

use crate::structs::Workspace;

pub fn save_workspace_to_config(filename: &str, ws: &Workspace) -> std::io::Result<()> {
    let mut config_dir = match dirs::config_dir() {
        Some(dir) => dir,
        None => {
            return Err(std::io::Error::new(
                std::io::ErrorKind::NotFound,
                "Config directory not found",
            ))
        }
    };

    config_dir.push("trueno"); // Replace with your app name
    if !config_dir.exists() {
        std::fs::create_dir_all(&config_dir)?;
    }

    let mut file_path = PathBuf::from(&config_dir);
    file_path.push(filename);
    let mut file = File::create(file_path)?;
    file.write_all(serde_json::to_string(ws).unwrap().as_bytes())?;
    Ok(())
}
