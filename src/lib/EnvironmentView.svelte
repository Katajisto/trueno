<script lang="ts">
  export let environment: Record<string, string>;
  export let missingSave: boolean;

  let new_key = "";
  let new_val = "";

  const addRow = () => {
    if(new_key === "") { return }
    missingSave = true;
    environment[new_key] = new_val;
    new_key = "";
    new_val = "";
  }

  const delKey = (key: string) => {  
    missingSave = true;
    delete environment[key];
    environment = environment;
  }
  
</script>

<table class="min-w-full bg-white">
  <thead class="bg-yellow-400 text-white">
    <tr>
      <th class="w-5/12 py-2">Key</th>
      <th class="w-5/12 py-2">Value</th>
      <th class="w-2/12 py-2">Action</th>
    </tr>
  </thead>
  <tbody class="text-gray-700">
    {#each Object.keys(environment) as key}
      <tr>
        <td class="border px-4 py-2">{key}</td>
        <td class="border px-4 py-2">
          <input 
            type="text" 
            class="shadow bg-gray-200 appearance-none border rounded w-full py-2 px-3"
            bind:value={environment[key]}
          />
        </td>
        <td class="border px-4 py-2 flex justify-center items-center">
          <button on:click={() => delKey(key)} class="p-2 bg-red-400 text-white font-bold px-5">Remove</button>
        </td>
      </tr>
    {/each}
      <tr>
        <td class="border bg-gray-200 px-4 py-2">
          <input 
            type="text" 
            class="shadow appearance-none border rounded w-full py-2 px-3"
            placeholder="Key"
            bind:value={new_key}
          />
        </td>
        <td class="border px-4 bg-gray-200 py-2">
          <input 
            type="text" 
            class="shadow appearance-none border rounded w-full py-2 px-3"
            placeholder="Value"
            bind:value={new_val}
          />
        </td>
        <td class="border px-4 bg-gray-200 py-2 flex justify-center items-center">
          <button on:click={addRow} class="p-2 bg-yellow-400 text-white font-bold px-5">Add</button>
        </td>
      </tr>
  </tbody>
</table>
