use serde::{Deserialize, Serialize};

use crate::get_state;

// Implement importing of a tree here.

// Implement a structure for the data you are going to import as structs,
// like in structs.rs. Make sure to derive Serialize/Deserialize for everything so you can deserialize the data

// stub
#[derive(Serialize, Deserialize)]
pub struct DataToImport {
    pub name: String,
}

#[tauri::command]
pub fn add_imported_tree(imported: DataToImport) /* -> bool or something */
{
    println!("{}", imported.name);
    // get a mutable reference to the current workspace
    let cur_ws = &mut get_state().workspaces[get_state().cur_workspace];
    // If you did the struct thingy correctly, imported will be auto parsed from the data
    // we send this from the frontend.

    // now transform the data into a tree folder structure....

    let result = crate::structs::Folder::new(
        cur_ws.get_new_id(), /* Use this to get IDs for you items. It is very important to have IDs */
        imported.name,
    );
    cur_ws.root_folder.sub_folders.push(result);
}
