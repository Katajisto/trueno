<script lang="ts">
  import { invoke } from "@tauri-apps/api/tauri";
  import EnvironmentView from "./EnvironmentView.svelte";
    import { refreshEnvironments } from "./stores/mainStore";
  export let environment;
  let missingSave = false;

  const save = async () => {
    missingSave = false;
    await invoke("save_environment", {env: environment});
    await refreshEnvironments();
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
    <label class="text-2xl" for="url">Workspace name: </label>
    <input name="url" class="text-3xl bg-gray-200 rounded-lg shadow p-2 my-2" on:input={() => missingSave = true} bind:value={environment.env_type["Named"]} /> 
    <EnvironmentView bind:missingSave={missingSave} bind:environment={environment.key_value} /> 
  </div>
</div>
