<script lang="ts">
  import Request from "./Request.svelte";
  import { focusItemType, focusItemData } from "./stores/mainStore"
  import Workspace from "./Workspace.svelte";
  import Environment from "./Environment.svelte";
  import Folder from "./Folder.svelte";
  import Import from "./Import.svelte";
</script>

<div class="h-full">
  {#if focusItemType === "request"}
    <Request request={focusItem["Request"]} />
  {/if}
  {#if focusItemType === "workspace"}
    <Workspace workspace={focusItem["Workspace"]} />
  {/if}
  {#if focusItemType === "environment"}
    <Environment environment={focusItem["Environment"]} />
  {/if}
  {#if focusItemType === "folder"}
    <Folder folder={focusItem["Folder"]} />
  {/if}
  {#if $focusItemType === "import"}
    <Import />
  {/if}
</div>
