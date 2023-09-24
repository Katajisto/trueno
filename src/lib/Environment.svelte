<script lang="ts">
  import { invoke } from "@tauri-apps/api/tauri";
  import EnvironmentView from "./EnvironmentView.svelte";
    import { curEnvironment, refreshEnvironments, selectedNode } from "./stores/mainStore";
  export let environment;
  let missingSave = false;

  const save = async () => {
    missingSave = false;
    await invoke("save_environment", {env: environment});
    await refreshEnvironments();
  }

  const delEnv = async () => {
    await invoke("delete_current_env");
    await refreshEnvironments();
    curEnvironment.set(0);
    selectedNode.set(0);
  }
  
</script>
<div>
  {#if missingSave}
  <div class="w-full bg-yellow-400 px-5 text-center text-2xl text-white p-2 flex justify-between">
    Unsaved changes!
    <button class="p-1 bg-yellow-600 rounded px-5" on:click={save}>Save</button>
  </div>
  {/if}
  <div class="p-3 flex h-full flex-col justify-stretch">  
    <label class="text-2xl" for="envName">Environment name: </label>
    <div class="flex w-full">
      <input name="envName" class="text-3xl bg-gray-200 rounded-lg shadow w-11/12 p-2 my-2" on:input={() => missingSave = true} bind:value={environment.env_type["Named"]} /> 
      <button on:click={delEnv} class="bg-red-500 px-2 my-2 text-white font-bold text-xl rounded ml-4 w-1/12">Delete</button>
    </div>
    <EnvironmentView bind:missingSave={missingSave} bind:environment={environment.key_value} /> 
  </div>
</div>
