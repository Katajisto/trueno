import {writable} from 'svelte/store'
import { invoke } from "@tauri-apps/api/tauri";

export const selectedNode = writable(-1);
export const tree = writable<any>({});

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


export const workspaces = writable<any>([]);

export const refreshWorkspaces = async () => {
  let res = await invoke("get_workspace_list");
  workspaces.set(res);  
}

export const environments = writable<any>([]);
export const curEnvironment = writable<number>(0);

curEnvironment.subscribe((v) => {
  invoke("set_cur_environment", {index: v});
  selectedNode.set(0);
})

export const refreshEnvironments = async () => {
    let res = await invoke("get_environment_list");
    environments.set(res);
}
