<script lang="ts">
  export let text = "button"
  export let onClick = () => {}
</script>

<button class="p-2 bg-gray-500 text-white m-2 rounded px-4" on:click={onClick}>{text}</button>
