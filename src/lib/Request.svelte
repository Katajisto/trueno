<script lang="ts">
  export let request;
  import jsonview from '@pgrabovets/json-view';
  import { onMount } from 'svelte';
  import { tree } from './stores/mainStore';
  import { invoke } from '@tauri-apps/api/tauri';

  let missingSave = false;
  let tab: "request" | "headers" | "scripts" = "request"
  let jsonTree = null;
  let hasMounted = false;
  let sending = false;
  let response: any = {};

  const renderTree = () => {
    if(!hasMounted) return;
    if(jsonTree != null) jsonview.destroy(jsonTree)
    jsonTree = jsonview.create(response)
    jsonview.render(jsonTree, document.querySelector("#jsonview"))
  }
  
  onMount(() => {
    hasMounted = true;
    renderTree()
  })

  $: response && renderTree()

  
  const save = () => {
    missingSave = false;
    invoke("save_request", {req: request}).then(newTree => tree.set(newTree))
  }

  const sendReq = async () => {
    sending = true;
    // get the pre and post scripts.
    let scripts: {pre: string[], post: string[]} = await invoke("get_pre_and_post_scripts", {req: request.id});
    let data = {hello: "asd"}
    console.log("Pre-pre-scripts: ", data)
    for (let script of scripts.pre) {
      console.log(script)
      let fn = eval(script);
      fn(data)
    }
    console.log("Post pre-scripts: ", data)
    
    let res = await invoke("send_request", {req: request});
    response = res;
    sending = false;
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
    <label class="text-2xl" for="url">Name: </label>
    <input name="url" class="text-3xl bg-gray-200 rounded-lg shadow p-2 my-2" on:input={() => missingSave = true} bind:value={request.name} /> 
    <label class="text-2xl" for="name">URL: </label>
    <div class="flex w-full">
      <select on:change={() => missingSave = true} class="w-1/12 my-2 mx-2 text-3xl bg-gray-200 rounded shadow" bind:value={request.method}>
        <option class="bg-gray-200" value="GET">GET</option>
        <option class="bg-gray-200" value="POST">POST</option>
      </select>
      <input name="name" class="w-10/12 text-3xl bg-gray-200 rounded shadow p-2 my-2" on:input={() => missingSave = true} bind:value={request.route} />
      <button on:click={sendReq} class="bg-yellow-500 px-2 my-2 text-white font-bold text-xl rounded ml-4 w-1/12">{sending ? "Sending it.." : `Send it⚡`}</button>
    </div>
    <div class="rounded mt-3 bg-gray-200 h-full w-full flex-col justify-stretch">
      <div class="rounded bg-gray-300 flex">
        <button class:selected={tab == "request"} on:click={() => tab = "request"} class="text-center p-2 text-2xl text-black font-bold bg-gray-300 rounded-t-lg flex-grow">Request view</button>
        <button class:selected={tab == "headers"} on:click={() => tab = "headers"} class="text-center p-2 text-2xl text-black font-bold bg-gray-300 rounded-t-lg flex-grow">Headers view</button>
        <button class:selected={tab == "scripts"} on:click={() => tab = "scripts"} class="text-center p-2 text-2xl text-black font-bold bg-gray-300 rounded-t-lg flex-grow">Scripts view</button>
      </div>
      <div class="flex items-stretch h-5/6 flex-grow">
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
</div>
<style>
  .selected {
    background-color: rgb(229, 231, 235);
  }

  #jsonview {
    overflow: auto;
    height: 100%;
    padding: 3px;
    font-family: 'monospace';
  }

  textarea {
    font-family: 'monospace';
    height: 100%;
    padding: 3px;
    padding-top: 10px;
  }
</style>

