<script lang="ts">
  export let text = "button"
  export let onClick = () => {}
</script>

<button class="p-2 bg-gray-300 text-black hover:bg-gray-500 hover:text-white m-2 rounded px-4" on:click={onClick}>{text}</button>
