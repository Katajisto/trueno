<script lang="ts">
    import CodeMirror from "svelte-codemirror-editor";
    import { javascript } from "@codemirror/lang-javascript";
    import { json } from "@codemirror/lang-json";

    export let onchange = () => {};
    export let value = "";
    export let lang: "js" | "json" = "js"
</script>
<div>
  <CodeMirror bind:value on:change={() => onchange()} lang={lang == "js" ? javascript() : json()} />
</div>
<style>
  div {
    font-size: 15px;
    text-align: left;
  }
</style>