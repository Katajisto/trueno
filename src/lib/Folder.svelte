<script lang="ts">
  import { invoke } from "@tauri-apps/api/tauri";
  import { reloadTree, selectedNode, tree } from "./stores/mainStore";
  import Editor from "./Editor.svelte";

  export let folder
  let missingSave = false

  const save = async () => {
    missingSave = false;
    await invoke("save_folder", {folder: folder})
    await reloadTree();
  }

  const delFolder = async () => {
    let res_tree = await invoke("delete_folder", {id: folder.id});
    tree.set(res_tree);
    selectedNode.set(0);
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
  <div class="flex w-full">
    <input name="url" class="text-3xl bg-gray-200 rounded-lg shadow p-2 my-2 w-11/12" on:input={() => missingSave = true} bind:value={folder.name} /> 
    <button on:click={delFolder} class="bg-red-500 px-2 my-2 text-white font-bold text-xl rounded ml-4 w-1/12">Delete</button>
  </div>
  <div class="flex items-center text-2xl">
    <input on:input={() => missingSave = true} name="stop_scripts" type="checkbox" bind:checked={folder.disable_parent_scripts} class="w-10 h-10" />
    <label for="stop_scripts" class="ml-4">Don't run parent scripts.</label>
  </div>
  <div class="flex px-4 text-2xl text-center w-full">
    <div class="w-1/2 p-4">
      <h2>Pre-script</h2>
      <Editor onchange={() => missingSave = true} bind:value={folder.pre_request_script} />
    </div>
    <div class="w-1/2 p-4">
      <h2>Post-script</h2>
      <Editor onchange={() => missingSave = true} bind:value={folder.post_request_script} />
    </div>
  </div>
</div>
