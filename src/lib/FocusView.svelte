<script lang="ts">
  import { invoke } from "@tauri-apps/api/tauri";
  import Request from "./Request.svelte";
  import { selectedNode } from "./stores/mainStore"
    import Workspace from "./Workspace.svelte";
    import Environment from "./Environment.svelte";
    import Folder from "./Folder.svelte";

  type focusType = "none" | "folder" | "request" | "workspace" | "environment";

  let focusItemType: focusType = "none"
  let focusItem = null

  const classifyFocusItem = (item): focusType  => {
    if(item["None"]) return "none"
    if(item["Folder"]) return "folder"
    if(item["Request"]) return "request"
    if(item["Workspace"]) return "workspace"
    if(item["Environment"]) return "environment"
    return "none"
  }

  selectedNode.subscribe(v => {
    console.log(v);
    invoke("get_current_focus_item", {curId: v}).then(focusItemData => {
      focusItem = focusItemData
      focusItemType = classifyFocusItem(focusItem);
    });
  })
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
</div>
