use crate::get_state;

pub fn insert_in_js_harness(scribula: String) -> String {
    let helpers = get_state().workspaces[get_state().cur_workspace]
        .helpers
        .clone();
    #[rustfmt::skip]
    return format!(
"// Trueno JS harness.
(data) => {{
{}
{}
}}",
        helpers, scribula
    );
}
