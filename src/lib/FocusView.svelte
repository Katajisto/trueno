<script lang="ts">
  import { invoke } from "@tauri-apps/api/tauri";
  import Request from "./Request.svelte";
  import { selectedNode } from "./stores/mainStore"

  type focusType = "none" | "folder" | "request";

  let focusItemType: focusType = "none"
  let focusItem = null

  const classifyFocusItem = (item): focusType  => {
    if(item["None"]) return "none"
    if(item["Folder"]) return "folder"
    if(item["Request"]) return "request"
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

<div>
  {#if focusItemType === "request"}
    <Request request={focusItem["Request"]} />
  {/if}
</div>
