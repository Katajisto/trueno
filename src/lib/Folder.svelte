<script lang="ts">
  import { invoke } from "@tauri-apps/api/tauri";
  import { reloadTree } from "./stores/mainStore";
    import App from "../App.svelte";

  export let folder
  let missingSave = false

  const save = async () => {
    missingSave = false;
    await invoke("save_folder", {folder: folder})
    await reloadTree();
  }
</script>

{#if missingSave}
  <div class="w-full bg-yellow-400 px-5 text-center text-2xl text-white p-2 flex justify-between">
    Unsaved changes!
    <button class="p-1 bg-yellow-600 rounded px-5" on:click={save}>Save</button>
  </div>
{/if}
<div class="flex flex-col px-5 py-5">
  <label class="text-2xl" for="url">Name: </label>
  <input name="url" on:input={() => missingSave = true} class="text-3xl bg-gray-200 rounded-lg shadow p-2 my-2" on:input={() => missingSave = true} bind:value={folder.name} /> 
  <div class="flex px-4 text-2xl text-center w-full">
    <div class="w-1/2 p-4">
      <h2>Pre-script</h2>
      <textarea on:input={() => missingSave = true} bind:value={folder.pre_request_script} class="bg-gray-200 w-full p-2" />
    </div>
    <div class="w-1/2 p-4">
      <h2>Post-script</h2>
      <textarea on:input={() => missingSave = true} bind:value={folder.post_request_script} class="bg-gray-200 w-full p-2" />
    </div>
  </div>
</div>
