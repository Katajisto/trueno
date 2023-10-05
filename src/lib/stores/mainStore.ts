import {get, writable} from 'svelte/store'
import { invoke } from "@tauri-apps/api/tauri";

export const selectedNode = writable(1);
export const tree = writable<any>({});
export const treeSummary = writable<string[]>([]);
export const focusItemData = writable<any>({});
export const focusItemType = writable<"none" | "folder" | "request" | "workspace" | "environment">("none");

selectedNode.subscribe(async v => {
  if(v === 0) {
    selectedNode.set(1); 
  }
  treeSummary.set(await invoke("get_req_tree_summary", {id: v}))
})

export const reloadTree = async () => {
  await invoke("get_ui_req_tree").then(data => tree.set(data));
}

export const curWorkspace = writable(0);

curWorkspace.subscribe(async v => {
  await invoke("set_cur_workspace", {num: v});
  selectedNode.set(0);
  curEnvironment.set(0);
  await reloadTree();
  await refreshEnvironments();
})

export const fuzzySuggestions = writable<any>([]);
export const getSuggestions = async (query) => {
  fuzzySuggestions.set(await invoke("get_fuzzy_results", {query: query}))
}

export const fuzzyQuery = writable("");

fuzzyQuery.subscribe(query => getSuggestions(query))

export const workspaces = writable<any>([]);

export const refreshWorkspaces = async () => {
  let res = await invoke("get_workspace_list");
  workspaces.set(res);  
}

export const environments = writable<any>([]);
export const curEnvironment = writable<number>(0);

export const refreshEnvironments = async () => {
    let res = await invoke("get_environment_list");
    environments.set(res);
}

const refreshFocusItem = (id: number) => {
  invoke("get_current_focus_item", {curId: id}).then(data => {
    focusItemData.set(data);
    focusItemType.set(classifyFocusItem(data));
  });
}

curEnvironment.subscribe((v) => {
  invoke("set_cur_environment", {index: v});
  refreshFocusItem(get(selectedNode));
})

export const refreshEnvironments = async () => {
    let res = await invoke("get_environment_list");
    environments.set(res);

type FocusType = "none" | "folder" | "request" | "workspace" | "environment" | "import";

const classifyFocusItem = (item): FocusType  => {
  console.log(item)

const classifyFocusItem = (item): focusType  => {
  if(item["None"]) return "none"
  if(item["Folder"]) return "folder"
  if(item["Request"]) return "request"
  if(item["Workspace"]) return "workspace"
  if(item["Environment"]) return "environment"
  if(item == "ImportJSON") return "import"
  return "none"
}

selectedNode.subscribe(v => {
  refreshFocusItem(v);
})
