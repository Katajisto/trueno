<script lang="ts">
  import FocusView from "./lib/FocusView.svelte"
  import Sidebar from "./lib/Sidebar.svelte";
  let curPage: 'home' | 'req' = 'home';
</script>

<div class="navbar bg-gray-200 shadow text-gray-700 font-bold flex py-2 px-2 items-center justify-between">
  <button class="hidden text-black bg-white rounded mr-5 p-2">Menu</button>
  <h1 class="text-3xl">⚡ TRUENO</h1>
  <h1 class="text-3xl mx-5 text-gray-400">V0.2</h1>
</div>
<main class="flex items-stretch">
  <Sidebar />
  <div class="h-auto w-full">
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