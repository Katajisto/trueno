<script lang="ts">
  import { invoke } from "@tauri-apps/api/tauri";
  import SidebarButton from "./SidebarButton.svelte";
  import TreeView from "./TreeView.svelte";
  import { selectedNode, tree } from "./stores/mainStore";
  import App from "../App.svelte";

  invoke("get_ui_req_tree").then(data => tree.set(data));

</script>

<div class="w-auto sidebar text-lg bg-gray-300 shadow flex flex-col justify-between">
  <div>
    <div class="flex p-2 justify-left">
      <h3 class="mr-2">Workspace:</h3>
      <select>
        <option>Initial workspace</option>
      </select>
    </div>
    <div class="flex p-2 justify-left">
      <h3 class="mr-2">Environment:</h3>
      <select>
        <option>Initial environment</option>
      </select>
    </div>
    <div class="tree bg-gray-200 text-black">
      <TreeView tree={$tree}></TreeView>
    </div>
  </div>
  <div class="flex bg-gray-400">
    <SidebarButton onClick={() => invoke('create_request', {name: "new_req", curId: $selectedNode}).then(data => tree.set(data))} text="Create new request" />
    <SidebarButton onClick={() => invoke('create_folder', {name: "folder", curId: $selectedNode}).then(data => tree.set(data))} text="Create new folder" />
  </div>
</div>

<style>
  .tree {
    overflow-y: scroll;
    overflow-x: auto;
    height: 70vh;
  }
  .sidebar {
    min-width: 300px;
  }
</style>
