<script lang="ts">
  import FocusView from "./lib/FocusView.svelte"
  import Sidebar from "./lib/Sidebar.svelte";
  let curPage: 'home' | 'req' = 'home';
  import conf from "../src-tauri/tauri.conf.json"
  import Fuzzy from "./lib/Fuzzy.svelte";
  import { fuzzyQuery, getSuggestions, treeSummary } from "./lib/stores/mainStore";

  let showFuzzy = false;

  const onKeyDown = (e) => {
    // Check if key input is going to to an input or textarea.
    if(!showFuzzy && (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA")) return;
    
    if(e.key === " " && !showFuzzy ) {
      showFuzzy = true;
      getSuggestions("");
      e.stopPropagation();
      e.preventDefault();
    }
    if(e.key === "Escape") {
      fuzzyQuery.set("");
      showFuzzy = false;
    }
  }
</script>

{#if showFuzzy}
<Fuzzy bind:open={showFuzzy} /> 
{/if}

<svelte:window on:keydown={onKeyDown} />

<div class="navbar bg-gray-200 shadow text-gray-700 font-bold flex py-2 px-2 items-center justify-between">
  <button class="hidden text-black bg-white rounded mr-5 p-2">Menu</button>
  <div class="flex items-center">
  <img class="h-14 mr-2" src="./logo.png" />
  <h1 class="text-5xl">TRUENO</h1>
  </div>
  <h1 class="text-2xl">{$treeSummary.join(" > ")}</h1>
  <h1 class="text-5xl mx-5 text-gray-400">V{conf.package.version}</h1>
</div>
<main class="flex items-stretch">
  <Sidebar />
  <div class="h-full w-5/6">
    <FocusView />
  </div>
</main>

<style>
  .navbar {
    height: 60px;
  }
  main {
    position: absolute;
    left: 0;
    right: 0;
    top: 60px;
    bottom: 0;
  }
</style>
