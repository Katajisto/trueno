<script lang="ts">
    import { invoke } from "@tauri-apps/api/tauri";
    import EnvironmentView from "./EnvironmentView.svelte";
    import { refreshWorkspaces } from "./stores/mainStore";

  export let workspace

  let missingSave = false

  const save = async () => {
    await invoke("save_workspace", {workspaceDto: workspace})
    await refreshWorkspaces();
    missingSave = false;
  }

</script>

<div class="h-full flex flex-col">
  {#if missingSave}
  <div class="w-full bg-yellow-400 px-5 text-center text-2xl text-white p-2 flex justify-between">
    Unsaved changes!
    <button class="p-1 bg-yellow-600 rounded px-5" on:click={save}>Save</button>
  </div>
  {/if}
  <div class="p-3 flex h-full flex-col justify-stretch">  
    <label class="text-2xl" for="url">Workspace name: </label>
    <input name="url" class="text-3xl bg-gray-200 rounded-lg shadow p-2 my-2" on:input={() => missingSave = true} bind:value={workspace.name} /> 
    <div class="h-1/2 bg-gray-200 rounded m-2 p-5 overflow-scroll">
      <label class="text-2xl" for="url">Environment: </label>
      <EnvironmentView bind:missingSave={missingSave} bind:environment={workspace.global_environ.key_value} />
    </div>
    <div class="h-1/2 bg-gray-200 rounded m-2 flex-col flex p-5 overflow-scroll">
      <label class="text-2xl" for="url">Helper functions (this will be appended to every script in this workspace): </label>
      <textarea on:input={() => missingSave = true} bind:value={workspace.helpers} class="h-full mt-2 p-4 font-mono" /> 
    </div>
  </div>
</div>
