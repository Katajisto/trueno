<script lang="ts">
  export let request;
  import jsonview from '@pgrabovets/json-view';
  import { onMount } from 'svelte';
  import { tree } from './stores/mainStore';
  import { invoke } from '@tauri-apps/api/tauri';

  let missingSave = false;
  let tab: "request" | "headers" | "scripts" = "request"
  onMount(() => {
    const tree = jsonview.create(request)
    // jsonview.expand(tree);
    jsonview.render(tree, document.querySelector("#jsonview"))
  })

  const save = () => {
    missingSave = false;
    invoke("save_request", {req: request}).then(newTree => tree.set(newTree))
  }
</script>
{#if missingSave}
<div class="w-full bg-yellow-400 px-5 text-center text-2xl text-white p-2 flex justify-between">
  Unsaved changes!
  <button class="p-1 bg-yellow-600 rounded px-5" on:click={save}>Save</button>
</div>
{/if}
<div class="p-3 flex flex-col">  
  <label class="text-2xl" for="name">Name: </label>
  <div class="flex w-full">
    <input name="name" class="w-11/12 text-3xl bg-gray-200 rounded shadow p-2 my-2" on:change={() => missingSave = true} bind:value={request.name} />
    <button class="bg-yellow-500 px-2 my-2 text-white font-bold text-xl rounded ml-4 w-1/12">Send it⚡</button>
  </div>
  <label class="text-2xl" for="url">URL: </label>
  <input name="url" class="text-3xl bg-gray-200 rounded-lg shadow p-2 my-2" on:change={() => missingSave = true} bind:value={request.route} /> 
  <div class="rounded mt-3 bg-gray-200 w-full">
    <div class="rounded bg-gray-300 flex">
      <button class:selected={tab == "request"} on:click={() => tab = "request"} class="text-center p-2 text-2xl text-black font-bold bg-gray-300 rounded-t-lg flex-grow">Request view</button>
      <button class:selected={tab == "headers"} on:click={() => tab = "headers"} class="text-center p-2 text-2xl text-black font-bold bg-gray-300 rounded-t-lg flex-grow">Headers view</button>
      <button class:selected={tab == "scripts"} on:click={() => tab = "scripts"} class="text-center p-2 text-2xl text-black font-bold bg-gray-300 rounded-t-lg flex-grow">Scripts view</button>
    </div>
    <div class="flex">
      <div class="w-1/2 p-2 m-2">
        <h2 class="text-center text-2xl my-2">Request</h2>
        <textarea class="w-full rounded shadow"></textarea>
      </div>
      <div class="w-1/2 p-2 m-2">
        <h2 class="text-center text-2xl my-2">Response</h2>
        <div id="jsonview"></div>
      </div>
    </div>
  </div>
</div>

<style>
  .selected {
    background-color: rgb(229, 231, 235);
  }

  #jsonview {
    overflow: auto;
    height: 500px;
    padding: 3px;
  }

  textarea {
    height: 500px;
    padding: 3px;
    padding-top: 10px;
  }
</style>

