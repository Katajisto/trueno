
<script context="module">
	const _expansionState = {
		/* treeNodeId: expanded <boolean> */
	}
</script>
<script>
	import {selectedNode} from './stores/mainStore'
//	import { slide } from 'svelte/transition'
	export let tree

	// @ts-ignore
	let expanded = _expansionState[tree.name] || false
	const toggleExpansion = (e) => {
		// @ts-ignore
	  expanded = _expansionState[tree.name  ] = !expanded
		if (expanded) {
			e.stopPropagation();
		}
	}
	$: arrowDown = expanded
</script>

<ul class=""><!-- transition:slide -->
	<li>
		{#if tree.children && tree.children.length > 0}
			<!-- svelte-ignore a11y-click-events-have-key-events -->
			<!-- svelte-ignore a11y-no-static-element-interactions -->
			<span class:selected={tree.id == $selectedNode} on:click={() => selectedNode.set(tree.id)} class="hover:text-gray-600 cursor-pointer py-2 font-bold text-xl" >
				<span on:click={toggleExpansion} class="arrow" class:arrowDown>&#x25b6</span>
				{tree.name                        }
			</span>
			{#if expanded}
				{#each tree.children as child}
					<svelte:self tree={child} />
				{/each}
			{/if}
		{:else}
			<span class:selected={tree.id == $selectedNode} on:click={selectedNode.set(tree.id)} class="cursor-pointer hover:text-gray-600 p-1 text-lg font-bold">
				<span class="no-arrow"/>
				{tree.name}
			</span>
		{/if}
	</li>
</ul>

<style>
	ul {
		margin: 0;
		list-style: none;
		padding-left: 0.9rem; 
		user-select: none;
	}
	.no-arrow { padding-left: 1.0rem; }
	.arrow {
		cursor: pointer;
		display: inline-block;
		/* transition: transform 200ms; */
	}
	.arrowDown { transform: rotate(90deg); }

	.selected {
		color: #DAA520;
	}
</style>
