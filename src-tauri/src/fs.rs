use dirs;
use std::fs::{self, File};
use std::io::{self, BufReader, Write};
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

pub fn load_workspaces_from_config() -> std::io::Result<Vec<Workspace>> {
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
        return Err(io::Error::new(
            io::ErrorKind::Other,
            "found no config dir workspaces",
        ));
    }

    let mut workspaces = Vec::new();
    let mut file_paths = Vec::new();

    for entry in fs::read_dir(config_dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.is_file() {
            file_paths.push(path);
        }
    }

    // Sort by the number in the filename
    file_paths.sort_by_key(|path| {
        path.file_stem()
            .and_then(|stem| stem.to_str())
            .and_then(|stem_str| stem_str.split('_').last())
            .and_then(|last| last.parse::<usize>().ok())
            .unwrap_or_else(|| {
                eprintln!("Couldn't parse number from filename: {:?}. We really really really would prefer you use the original file names. Please rename your file to match workspace_INTEGER.json", path);
                9999
            })
    });

    for path in file_paths {
        let file = match File::open(&path) {
            Ok(file) => file,
            Err(_) => {
                eprintln!(
                    "Skipped file {:?} due to loading error",
                    path.file_name().unwrap()
                );
                continue;
            } // Skip this file and move to the next
        };

        let reader = BufReader::new(file);

        match serde_json::from_reader::<BufReader<File>, Workspace>(reader) {
            // Deserialize into your Workspace type
            Ok(workspace) => workspaces.push(workspace),
            Err(_) => {
                eprintln!(
                    "Failed to load workspace from file: {:?}",
                    path.file_name().unwrap()
                );
                continue;
            }
        }
    }

    if workspaces.len() == 0 {
        return Err(io::Error::new(io::ErrorKind::Other, "found 0 workspaces"));
    }
    Ok(workspaces)
}
