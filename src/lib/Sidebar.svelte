<script lang="ts">
  import { invoke } from "@tauri-apps/api/tauri";
  import SidebarButton from "./SidebarButton.svelte";
  import TreeView from "./TreeView.svelte";
  import { curWorkspace, selectedNode, tree, workspaces, curEnvironment, refreshWorkspaces, refreshEnvironments, environments } from "./stores/mainStore";
  import { onMount } from "svelte";

  onMount(async () => {
    refreshWorkspaces()
    refreshEnvironments()
  })

  const createWorkspace = async () => {
    await invoke("new_workspace");
    refreshWorkspaces();
    refreshEnvironments();
  }

  const createEnvironment = async () => {
    await invoke("add_environment");
    refreshEnvironments();
  }
  
</script>

<div class="w-1/6 sidebar text-sm bg-gray-300 shadow flex flex-col justify-between">
  <div>
    <div class="flex p-2 justify-left items-center">
      <h3 class="mr-2">Workspace:</h3>
      <select class="w-28" bind:value={$curWorkspace}>
        {#each $workspaces as ws}
          <option value={ws[0]}>{ws[1]}</option>
        {/each}
      </select>
      <button on:click={createWorkspace} class=" bg-gray-100 rounded shadow m-1 w-7 h-7 text-center">+</button>
      <button on:click={() => selectedNode.set(-1)} class=" bg-gray-100 rounded shadow m-1 w-7 h-7 text-center">⚙️</button>
    </div>
    <div class="flex p-2 justify-left items-center">
      <h3 class="mr-2">Environment:</h3>
      <select class="w-28" bind:value={$curEnvironment}>
        {#each $environments as environ}
          <option value={environ[0]}>{environ[1]}</option>
        {/each}
      </select>
      <button on:click={createEnvironment} class=" bg-gray-100 rounded shadow m-1 w-7 h-7 text-center">+</button>
      <button on:click={() => selectedNode.set(-2)} class=" bg-gray-100 rounded m-1 shadow w-7 h-7 text-center">⚙️</button>
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
