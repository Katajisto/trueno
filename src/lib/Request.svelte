<script lang="ts">
  export let request;
  import { onMount } from 'svelte';
  import { selectedNode, tree } from './stores/mainStore';
  import { invoke } from '@tauri-apps/api/tauri';
  import EnvironmentView from './EnvironmentView.svelte';
  import Spinner from './Spinner.svelte'
  import { JsonView } from '@zerodevx/svelte-json-view'  

  let missingSave = false;
  let tab: "request" | "headers" | "scripts" = "request"
  let jsonTree = null;
  let hasMounted = false;
  let sending = false;
  let response: any = {};

  const save = async () => {
    await invoke("save_request", {req: request}).then(newTree => tree.set(newTree))
    missingSave = false;
  }

  const sendReq = async () => {
    await save();
    response = {};
    sending = true;
    // get the pre and post scripts.
    let scripts: {pre: string[], post: string[]} = await invoke("get_pre_and_post_scripts", {req: request.id});
    let data = await invoke("get_js_datadump", {id: request.id});
    let abstractData = {
      requestEnv: data.resolvedEnv.key_value,
      globalEnv: data.globalEnv.key_value,
      currentEnv: data.currentEnv.key_value,
      request: data.request,
    }
  
    console.log("Data pre pre-scripts: ", abstractData)
    for (let script of scripts.pre) {
      let fn = eval(script);
      fn(abstractData)
    }
    console.log("Data post pre-scripts: ", abstractData)
    data.requestEnv.key_value = abstractData.requestEnv;
    data.globalEnv.key_value = abstractData.globalEnv;
    data.currentEnv.key_value = abstractData.currentEnv;
    data.request = abstractData.request;
    
    let res = await invoke("send_request", {req: data.request, datadumpAfterScripts: data});
    abstractData.response = {...res};
    for (let script of scripts.post) {
      let fn = eval(script);
      fn(abstractData)
    }

    data.requestEnv.key_value = abstractData.requestEnv;
    data.globalEnv.key_value = abstractData.globalEnv;
    data.currentEnv.key_value = abstractData.currentEnv;
    data.request = abstractData.request;
    
    console.log("Data post post-scripts: ", abstractData)
    
    await invoke("post_js_datadump", {data: data})
    response = res;
    try {
      response.body = JSON.parse(res.body);
    } catch(e) {
      console.log(e);
      response.body = res.body;
    }
  
    sending = false;
  }

  const delRequest = async () => {
    let res_tree = await invoke("delete_request", {id: request.id});
    tree.set(res_tree);
    selectedNode.set(0);
  }
  
</script>
<div class="main h-full w-full flex flex-col">
  {#if missingSave}
  <div class="w-full bg-yellow-400 px-5 text-center text-2xl text-white p-2 flex justify-between">
    Unsaved changes!
    <button class="p-1 bg-yellow-600 rounded px-5" on:click={save}>Save</button>
  </div>
  {/if}
  <div class="p-3 flex h-full flex-col">  
    <label class="text-2xl" for="url">Name: </label>
    <div class="flex w-full">
      <input name="url" class="text-3xl bg-gray-200 rounded-lg shadow p-2 my-2 w-11/12" on:input={() => missingSave = true} bind:value={request.name} /> 
      <button on:click={delRequest} class="bg-red-500 px-2 my-2 text-white font-bold text-xl rounded ml-4 w-1/12">Delete</button>
    </div>
    <label class="text-2xl" for="name">URL: </label>
    <div class="flex w-full">
      <select on:change={() => missingSave = true} class="w-1/12 my-2 mx-2 text-3xl bg-gray-200 rounded shadow" bind:value={request.method}>
        <option class="bg-gray-200" value="GET">GET</option>
        <option class="bg-gray-200" value="POST">POST</option>
        <option class="bg-gray-200" value="PATCH">PATCH</option>
        <option class="bg-gray-200" value="DELETE">DELETE</option>
      </select>
      <input name="name" class="w-10/12 text-3xl bg-gray-200 rounded shadow p-2 my-2" on:input={() => missingSave = true} bind:value={request.route} />
      <button on:click={sendReq} class="bg-yellow-500 px-2 my-2 text-white font-bold text-xl rounded ml-4 w-1/12">{sending ? "Sending it.." : `Send it⚡`}</button>
    </div>
    <div class="rounded bg-gray-300 mt-2 flex">
      <button class:selected={tab == "request"} on:click={() => tab = "request"} class="text-center p-2 text-2xl text-black font-bold bg-gray-300 rounded-t-lg flex-grow">Request view</button>
      <button class:selected={tab == "headers"} on:click={() => tab = "headers"} class="text-center p-2 text-2xl text-black font-bold bg-gray-300 rounded-t-lg flex-grow">Headers view</button>
      <button class:selected={tab == "scripts"} on:click={() => tab = "scripts"} class="text-center p-2 text-2xl text-black font-bold bg-gray-300 rounded-t-lg flex-grow">Scripts view</button>
    </div>
    <div class="rounded request-data-container mt-0 bg-gray-200 w-full flex-col justify-stretch">
      {#if tab == "request"}
      <div class="flex top-req-c">
        <div class="w-1/2 p-2 m-2">
          <h2 class="text-center text-2xl my-2">Request</h2>
            <div class="res-container">
            <div class="res-scroll-container">
              <textarea bind:value={request.body} on:input={() => missingSave = true} class="w-full rounded shadow"></textarea>
            </div>
            </div>
        </div>
        <div class="w-1/2 p-2 m-2">
          <h2 class="text-center text-2xl my-2">Response</h2>
            <div class="res-container">
            <div class="res-scroll-container">
            {#if sending}
              <Spinner /> 
            {:else}
              <JsonView json={response } />
            {/if}
            </div>
            </div>
        </div>
      </div>
      {/if}
      {#if tab == "headers"}
      <EnvironmentView bind:environment={request.headers} bind:missingSave={missingSave}/>
      {/if}
      {#if tab == "scripts"}
      <div class="flex px-4 text-2xl text-center w-full">
        <div class="w-1/2 p-4">
          <h2>Pre-script</h2>
          <textarea on:input={() => missingSave = true} bind:value={request.pre_script} class="bg-white w-full p-2" />
        </div>
        <div class="w-1/2 p-4">
          <h2>Post-script</h2>
          <textarea on:input={() => missingSave = true} bind:value={request.post_script} class="bg-white w-full p-2" />
        </div>
      </div>
      {/if}
    </div>
  </div>
</div>
<style>
  .selected {
    background-color: rgb(229, 231, 235);
  }

  .res-container {
    overflow: auto;
    height: 90%;
    padding: 3px;
    font-family: 'monospace';
    flex: 1 1 0;
    
  }

  .res-scroll-container {
    max-height: 100%;
    overflow: auto;
  }

  textarea {
    font-family: 'monospace';
    height: 100%;
    padding: 3px;
    padding-top: 10px;
  }

  .top-req-c {
    max-height: 100%;
  }

  .hidden {
    display: none;
  }
  
  .request-data-container {
    flex: 1 1 auto;
    height: 100%;
    width: 100%;
    overflow: auto;
  }

  .main {
    max-width: 100%;
  }
  
</style>

