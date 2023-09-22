import {writable} from 'svelte/store'

export let selectedNode = writable(-1);
export let tree = writable<any>({});