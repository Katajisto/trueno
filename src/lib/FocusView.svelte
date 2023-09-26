<script lang="ts">
  import { invoke } from "@tauri-apps/api/tauri";
  import Request from "./Request.svelte";
  import { focusItemType, focusItemData } from "./stores/mainStore"
  import Workspace from "./Workspace.svelte";
  import Environment from "./Environment.svelte";
  import Folder from "./Folder.svelte";
</script>

<div class="h-full">
  {#if $focusItemType === "request"}
    <Request request={$focusItemData["Request"]} />
  {/if}
  {#if $focusItemType === "workspace"}
    <Workspace workspace={$focusItemData["Workspace"]} />
  {/if}
  {#if $focusItemType === "environment"}
    <Environment environment={$focusItemData["Environment"]} />
  {/if}
  {#if $focusItemType === "folder"}
    <Folder folder={$focusItemData["Folder"]} />
  {/if}
</div>
