<script>
    import { invoke } from "@tauri-apps/api/tauri";
    import { reloadTree } from "./stores/mainStore";


  let data = "";

  $: data = data.replaceAll('“', '"')
  $: data = data.replaceAll('”', '"')
</script>

<div class="px-4">
  <h2 class="text-center text-2xl mt-10">Enter JSON to import</h2>
  <textarea class="h-52 bg-gray-100 w-full" bind:value={data}></textarea>
  <button class="p-2 bg-gray-200 w-full text-gray-600" on:click={async () => {await invoke("add_imported_tree", {imported: JSON.parse(data)}); reloadTree();}}>Import</button>
</div>