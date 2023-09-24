<script lang="ts">
  import { invoke } from "@tauri-apps/api/tauri";
  import { onMount } from "svelte";
    import { curEnvironment, curWorkspace, fuzzyQuery, fuzzySuggestions, selectedNode } from "./stores/mainStore";

  export let open;
  let searchInput
  let query = "";
  let curOption = 0;

  onMount(() => {
    searchInput.focus(); 
  })

  
  const onKeyDown = (e) => {
    if(e.key === "ArrowDown") {
      e.preventDefault();
      curOption += 1;
    }
    if(e.key === "Tab") {
      e.preventDefault();
      curOption += 1;
    }
    if(e.key === "ArrowUp") {
      e.preventDefault();
      curOption -= 1;
    }
    if(e.key === "Enter") {
      fuzzyQuery.set("")
      let selectedOpt = $fuzzySuggestions[curOption];
      if(selectedOpt.result_type === "Workspace") {
        curWorkspace.set(selectedOpt.id)
      } else if (selectedOpt.result_type === "Environment") {
        curEnvironment.set(selectedOpt.id)
      } else {
        selectedNode.set(selectedOpt.id);
      }
      open = false;
    }
    if (curOption < 0) curOption = $fuzzySuggestions.length - 1;
    if (curOption > $fuzzySuggestions.length - 1) curOption = 0;
  }

  const typeToEmoji = (type: "Folder" | "Request" | "Settings") => {
    const table = {
      "Folder": "📁",
      "Request": "📬",
      "Settings": "⚙️",
      "Environment": "🌍",
      "Workspace": "💼",
    }
    return table[type];
  }
</script>

<svelte:window on:keydown={onKeyDown} />

<div class="flex items-center justify-center fixed z-10 top-0 bottom-0 left-0 right-0 blur-bg">
  <div class="p-2 rounded bg-white w-4/6">
    <input bind:value={$fuzzyQuery} bind:this={searchInput} on:blur={() => setTimeout(() => searchInput.focus(), 20)} placeholder="What do you seek?" class="text-3xl text-gray-400 p-2 w-full bg-gray-300" />
    {#each $fuzzySuggestions as result, i}
    <div class:selected={i === curOption} class="text-3xl text-gray-500 p-2 w-full flex justify-between bg-gray-200 my-2 roundeds shadow">
      <h2>{typeToEmoji(result.result_type)} {result.name}</h2>
      <h2 class="font-bold">{result.distance}</h2>
    </div>
    {/each}
  </div>
</div>

<style>
  .blur-bg {
    background-color: rgba(0,0,0,0.2);
    backdrop-filter: blur(6px);
    -webkit-backdrop-filter: blur(6px);
  }

  .selected {
    background-color: #FFD700;
  }
</style>
